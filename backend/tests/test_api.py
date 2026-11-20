from collections.abc import Iterator
from datetime import date
from io import BytesIO
from pathlib import Path

import pytest
from fastapi.testclient import TestClient
from openpyxl import load_workbook
from sqlalchemy.orm import Session

from app.api.deps import get_file_store, get_today
from app.api.main import app
from app.core.config import Settings, get_settings
from app.db.session import get_session
from app.providers.storage import FileStore

TODAY = date(2026, 11, 16)


def make_settings(**changes: object) -> Settings:
    fields: dict[str, object] = {
        "database_url": "sqlite://",
        "llm_provider": "fake",
        "llm_model": "test",
        "demo_mode": True,
    }
    return Settings(_env_file=None, **(fields | changes))


@pytest.fixture
def client(session: Session, files: FileStore) -> Iterator[TestClient]:
    app.dependency_overrides = {
        get_session: lambda: session,
        get_settings: lambda: make_settings(),
        get_file_store: lambda: files,
        get_today: lambda: lambda: TODAY,
    }
    with TestClient(app) as client:
        yield client
    app.dependency_overrides = {}


@pytest.fixture
def demo(client: TestClient) -> TestClient:
    response = client.post("/ingest/demo")
    assert response.status_code == 200
    return client


def first(client: TestClient, status: str) -> dict:
    return client.get("/invoices", params={"status": status}).json()[0]


def test_health(client: TestClient) -> None:
    assert client.get("/health").json() == {"status": "ok", "demo_mode": True}


def test_load_demo_and_list(demo: TestClient) -> None:
    assert len(demo.get("/invoices").json()) == 38
    assert len(demo.get("/invoices", params={"status": "needs_review"}).json()) == 5
    assert demo.get("/invoices", params={"status": "nope"}).status_code == 422


def test_demo_is_refused_when_demo_mode_is_off(client: TestClient) -> None:
    app.dependency_overrides[get_settings] = lambda: make_settings(demo_mode=False)
    assert client.post("/ingest/demo").status_code == 403


def test_get_invoice_and_its_document(demo: TestClient) -> None:
    invoice = first(demo, "needs_review")
    assert demo.get(f"/invoices/{invoice['id']}").json() == invoice

    document = demo.get(f"/invoices/{invoice['id']}/document")
    assert document.headers["content-type"] == "application/pdf"
    assert document.content.startswith(b"%PDF")

    assert demo.get("/invoices/9999").status_code == 404
    assert demo.get("/invoices/9999/document").status_code == 404


def test_review_corrects_and_approves(demo: TestClient) -> None:
    invoice = first(demo, "needs_review")
    fields = {name: invoice[name] for name in ("supplier", "invoice_number", "issue_date")} | {
        "net_amount": "100.00",
        "vat_rate": "21",
        "vat_amount": "21.00",
        "total": "121.00",
        "currency": "EUR",
        "confidence": 0.99,
    }

    saved = demo.put(f"/invoices/{invoice['id']}", json={"fields": fields}).json()
    assert (saved["status"], saved["approved"], saved["total"]) == ("ok", False, "121.00")

    wrong = fields | {"total": "1.00"}
    approved = demo.put(f"/invoices/{invoice['id']}", json={"fields": wrong, "approve": True})
    assert (approved.json()["status"], approved.json()["approved"]) == ("ok", True)

    invalid = demo.put(f"/invoices/{invoice['id']}", json={"fields": fields | {"currency": "euro"}})
    assert invalid.status_code == 422
    assert demo.put("/invoices/9999", json={"fields": fields}).status_code == 404


def test_mark_duplicate(demo: TestClient) -> None:
    invoice = first(demo, "ok")
    marked = demo.post(f"/invoices/{invoice['id']}/duplicate").json()
    assert marked["status"] == "duplicate"
    assert demo.post("/invoices/9999/duplicate").status_code == 404


def test_upload_reads_known_files_and_rejects_the_rest(demo: TestClient) -> None:
    known = demo.get(f"/invoices/{first(demo, 'ok')['id']}/document").content
    response = demo.post(
        "/ingest/upload",
        files=[
            ("files", ("again.pdf", known, "application/pdf")),
            ("files", ("unknown.pdf", b"%PDF-new", "application/pdf")),
            ("files", ("notes.txt", b"hello", "text/plain")),
        ],
    )
    # The first one is the same file under another name; the fake model cannot read the second.
    assert response.json() == {
        "stored": 1,
        "skipped": 0,
        "failed": ["unknown.pdf"],
        "rejected": ["notes.txt"],
    }


def test_read_folder(client: TestClient, tmp_path: Path) -> None:
    assert client.post("/ingest/folder").status_code == 503

    folder = tmp_path / "inbox"
    folder.mkdir()
    (folder / "scan.pdf").write_bytes(b"%PDF-x")
    app.dependency_overrides[get_settings] = lambda: make_settings(invoice_folder=str(folder))
    assert client.post("/ingest/folder").json() == {
        "stored": 0,
        "skipped": 0,
        "failed": ["scan.pdf"],
    }


def test_the_real_model_without_a_key_answers_503(client: TestClient) -> None:
    app.dependency_overrides[get_settings] = lambda: make_settings(llm_provider="openrouter")
    files = [("files", ("a.pdf", b"%PDF", "application/pdf"))]
    response = client.post("/ingest/upload", files=files)
    assert response.status_code == 503
    assert "OPENROUTER_API_KEY is empty" in response.json()["detail"]


def test_metrics(demo: TestClient) -> None:
    metrics = demo.get("/metrics").json()
    assert (metrics["invoices"], metrics["ok"], metrics["needs_review"], metrics["duplicates"]) == (
        38,
        31,
        5,
        2,
    )
    assert len(metrics["spend_by_month"]) == 6


def test_export(demo: TestClient) -> None:
    response = demo.get("/export")
    assert response.headers["content-type"].startswith("application/vnd.openxmlformats")
    assert 'filename="invoices-2026-11-16.xlsx"' in response.headers["content-disposition"]
    workbook = load_workbook(BytesIO(response.content))
    assert workbook.sheetnames[0] == "2026-11"


def test_export_summary_matches_the_workbook(demo: TestClient) -> None:
    summary = demo.get("/export/summary").json()
    workbook = load_workbook(BytesIO(demo.get("/export").content))

    assert summary["file_name"] == "invoices-2026-11-16.xlsx"
    assert [sheet["name"] for sheet in summary["sheets"]] == workbook.sheetnames
    assert sum(sheet["invoices"] for sheet in summary["sheets"]) == 31
    assert (summary["needs_review"], summary["duplicates"]) == (5, 2)


def test_the_openapi_description_lists_every_endpoint(client: TestClient) -> None:
    paths = set(client.get("/openapi.json").json()["paths"])
    assert paths == {
        "/health",
        "/invoices",
        "/invoices/{invoice_id}",
        "/invoices/{invoice_id}/document",
        "/invoices/{invoice_id}/preview",
        "/invoices/{invoice_id}/duplicate",
        "/ingest/upload",
        "/ingest/folder",
        "/ingest/demo",
        "/metrics",
        "/export",
        "/export/summary",
    }


def test_preview_draws_the_first_page(demo: TestClient) -> None:
    invoice = first(demo, "needs_review")
    response = demo.get(f"/invoices/{invoice['id']}/preview")
    assert response.headers["content-type"] == "image/png"
    assert response.content.startswith(b"\x89PNG")
    assert demo.get("/invoices/9999/preview").status_code == 404


def test_doubtful_fields_point_at_what_to_check(demo: TestClient) -> None:
    to_review = demo.get("/invoices", params={"status": "needs_review"}).json()
    flagged = {field for invoice in to_review for field in invoice["doubtful_fields"]}
    assert "total" in flagged
    assert all(invoice["doubtful_fields"] for invoice in to_review)
    assert first(demo, "ok")["doubtful_fields"] == []
    duplicate = first(demo, "duplicate")
    assert "invoice_number" in duplicate["doubtful_fields"]
