from datetime import date, timedelta
from decimal import Decimal
from io import BytesIO

from openpyxl import load_workbook
from sqlalchemy.orm import Session

from app.db.repositories import InvoiceRepository
from app.domain.models import Extraction, Invoice, InvoiceFile, InvoiceStatus
from app.providers.llm.base import ExtractionError, LLMProvider
from app.providers.source.base import InvoiceSource
from app.providers.storage import FileStore
from app.services.checks import assess, duplicate_reason, review_reasons
from app.services.demo import reload_demo
from app.services.export import build_workbook
from app.services.ingest import IngestService
from app.services.metrics import compute_metrics
from app.services.review import MARKED_DUPLICATE, ReviewService
from tests.helpers import make_extraction

TODAY = date(2026, 11, 16)


def today() -> date:
    return TODAY


class ListSource(InvoiceSource):
    def __init__(self, files: list[InvoiceFile]) -> None:
        self.files = files

    def fetch(self) -> list[InvoiceFile]:
        return self.files


class ScriptedLLM(LLMProvider):
    """Answers with the extraction prepared for each file name, and counts the calls."""

    def __init__(self, answers: dict[str, Extraction]) -> None:
        self.answers = answers
        self.calls: list[str] = []

    def extract(self, file: InvoiceFile) -> Extraction:
        self.calls.append(file.file_name)
        if file.file_name not in self.answers:
            raise ExtractionError("unreadable")
        return self.answers[file.file_name]


def store(session: Session, status: InvoiceStatus = InvoiceStatus.OK, **changes: object) -> Invoice:
    file_name = str(changes.pop("file_name", "a.pdf"))
    return InvoiceRepository(session).add(
        make_extraction(**changes),
        file_name=file_name,
        file_hash=file_name,
        status=status,
        review_reasons=[],
    )


# Checks


def test_a_correct_invoice_has_no_reasons() -> None:
    assert review_reasons(make_extraction(), TODAY) == []


def test_a_total_that_does_not_add_up_is_a_reason() -> None:
    reasons = review_reasons(make_extraction(total=Decimal("1510.40")), TODAY)
    assert reasons == ["Net amount plus VAT is 1500.40, but the total says 1510.40."]


def test_vat_that_does_not_match_the_rate_is_a_reason() -> None:
    extraction = make_extraction(vat_amount=Decimal("250.00"), total=Decimal("1490.00"))
    assert review_reasons(extraction, TODAY) == [
        "VAT at 21% should be 260.40, but the invoice says 250.00."
    ]


def test_low_confidence_and_a_future_date_are_reasons() -> None:
    extraction = make_extraction(confidence=0.58, issue_date=TODAY + timedelta(days=1))
    assert review_reasons(extraction, TODAY) == [
        "The reading is not reliable (confidence 58%).",
        "The issue date is in the future.",
    ]


def test_same_supplier_and_number_is_a_duplicate(session: Session) -> None:
    repository = InvoiceRepository(session)
    stored = store(session, file_name="first.pdf")
    repeated = make_extraction(supplier="NORTHLAKE PAPER")

    assert duplicate_reason(repository, repeated) == (
        "Same supplier and invoice number as first.pdf."
    )
    assert duplicate_reason(repository, repeated, exclude_id=stored.id) is None
    assert duplicate_reason(repository, make_extraction(invoice_number="OTHER-1")) is None


def test_a_stored_duplicate_does_not_make_the_original_one(session: Session) -> None:
    store(session, InvoiceStatus.DUPLICATE, file_name="copy.pdf")
    assert duplicate_reason(InvoiceRepository(session), make_extraction()) is None


def test_assess_gives_the_status(session: Session) -> None:
    repository = InvoiceRepository(session)
    assert assess(repository, make_extraction(), TODAY) == (InvoiceStatus.OK, [])

    status, reasons = assess(repository, make_extraction(confidence=0.5), TODAY)
    assert status == InvoiceStatus.NEEDS_REVIEW
    assert len(reasons) == 1

    store(session, file_name="first.pdf")
    status, reasons = assess(repository, make_extraction(confidence=0.5), TODAY)
    assert status == InvoiceStatus.DUPLICATE
    assert reasons[0] == "Same supplier and invoice number as first.pdf."
    assert len(reasons) == 2


# Ingest


def test_ingest_stores_each_invoice_with_its_status(session: Session, files: FileStore) -> None:
    documents = [
        InvoiceFile(file_name="good.pdf", content=b"1"),
        InvoiceFile(file_name="wrong-total.pdf", content=b"2"),
        InvoiceFile(file_name="resent.pdf", content=b"3"),
        InvoiceFile(file_name="copy.pdf", content=b"1"),
        InvoiceFile(file_name="unreadable.pdf", content=b"4"),
    ]
    llm = ScriptedLLM(
        {
            "good.pdf": make_extraction(),
            "wrong-total.pdf": make_extraction(invoice_number="B-2", total=Decimal("1.00")),
            "resent.pdf": make_extraction(),
        }
    )

    result = IngestService(ListSource(documents), llm, session, files, today).run()

    assert (result.stored, result.skipped, result.failed) == (4, 0, ["unreadable.pdf"])
    statuses = {i.file_name: i.status for i in InvoiceRepository(session).list_all()}
    assert statuses == {
        "good.pdf": InvoiceStatus.OK,
        "wrong-total.pdf": InvoiceStatus.NEEDS_REVIEW,
        "resent.pdf": InvoiceStatus.DUPLICATE,
        "copy.pdf": InvoiceStatus.DUPLICATE,
    }
    # The byte-for-byte copy is never sent to the model.
    assert "copy.pdf" not in llm.calls
    # Every document is kept for the review screen, the unreadable one too.
    assert files.load(documents[4].file_hash) == b"4"


def test_ingest_twice_stores_nothing_twice(session: Session, files: FileStore) -> None:
    documents = [
        InvoiceFile(file_name="good.pdf", content=b"1"),
        InvoiceFile(file_name="copy.pdf", content=b"1"),
    ]
    llm = ScriptedLLM({"good.pdf": make_extraction()})
    service = IngestService(ListSource(documents), llm, session, files, today)

    service.run()
    second = service.run()

    assert (second.stored, second.skipped) == (0, 2)
    assert len(InvoiceRepository(session).list_all()) == 2
    assert llm.calls == ["good.pdf"]


def test_the_demo_set_shows_every_case(session: Session, files: FileStore) -> None:
    result = reload_demo(session, files, today)
    repository = InvoiceRepository(session)

    assert (result.stored, result.failed) == (38, [])
    assert len(repository.list_all(InvoiceStatus.NEEDS_REVIEW)) == 5
    duplicates = repository.list_all(InvoiceStatus.DUPLICATE)
    assert sorted(reason.split(" as ")[0] for d in duplicates for reason in d.review_reasons) == [
        "Same file",
        "Same supplier and invoice number",
    ]
    # The later file is the one set aside, not the original.
    assert all("resent" in d.file_name or "copy" in d.file_name for d in duplicates)
    assert len(repository.list_all(InvoiceStatus.OK)) == 31

    # Loading it again replaces the data instead of adding to it.
    reload_demo(session, files, today)
    assert len(repository.list_all()) == 38


# Review


def test_saving_without_approval_runs_the_checks_again(session: Session) -> None:
    invoice = store(session, InvoiceStatus.NEEDS_REVIEW, total=Decimal("1.00"))
    service = ReviewService(session, today)

    still_wrong = service.save(invoice.id, make_extraction(total=Decimal("2.00")), approve=False)
    assert still_wrong.status == InvoiceStatus.NEEDS_REVIEW
    assert not still_wrong.approved

    fixed = service.save(invoice.id, make_extraction(), approve=False)
    assert (fixed.status, fixed.review_reasons, fixed.approved) == (InvoiceStatus.OK, [], False)


def test_approval_makes_the_invoice_ok(session: Session) -> None:
    invoice = store(session, InvoiceStatus.NEEDS_REVIEW, confidence=0.5)
    saved = ReviewService(session, today).save(
        invoice.id, make_extraction(confidence=0.5, supplier="Fixed name"), approve=True
    )
    assert (saved.status, saved.review_reasons, saved.approved) == (InvoiceStatus.OK, [], True)
    assert saved.supplier == "Fixed name"


def test_mark_duplicate(session: Session) -> None:
    invoice = store(session)
    marked = ReviewService(session, today).mark_duplicate(invoice.id)
    assert (marked.status, marked.review_reasons) == (InvoiceStatus.DUPLICATE, [MARKED_DUPLICATE])


def test_review_of_a_missing_invoice_returns_none(session: Session) -> None:
    service = ReviewService(session, today)
    assert service.save(999, make_extraction(), approve=True) is None
    assert service.mark_duplicate(999) is None


# Export


def test_workbook_has_one_sheet_per_month_with_totals(session: Session) -> None:
    store(session, file_name="nov-1.pdf", invoice_number="N1")
    store(session, file_name="nov-2.pdf", invoice_number="N2", issue_date=date(2026, 11, 2))
    store(session, file_name="oct.pdf", invoice_number="O1", issue_date=date(2026, 10, 5))
    store(session, InvoiceStatus.NEEDS_REVIEW, file_name="review.pdf", invoice_number="R1")
    store(session, InvoiceStatus.DUPLICATE, file_name="dup.pdf", invoice_number="D1")

    content = build_workbook(InvoiceRepository(session).list_all())
    workbook = load_workbook(BytesIO(content))

    assert workbook.sheetnames == ["2026-11", "2026-10"]
    rows = list(workbook["2026-11"].iter_rows(values_only=True))
    assert rows[0][:3] == ("Date", "Supplier", "Invoice number")
    assert [row[8] for row in rows[1:3]] == ["nov-2.pdf", "nov-1.pdf"]
    assert rows[3] == ("Total", None, None, 2480, None, 520.8, 3000.8, "EUR", None)
    assert len(rows) == 4


def test_workbook_keeps_totals_per_currency(session: Session) -> None:
    store(session, file_name="eur.pdf", invoice_number="E1")
    store(session, file_name="usd.pdf", invoice_number="U1", currency="USD")

    workbook = load_workbook(BytesIO(build_workbook(InvoiceRepository(session).list_all())))
    rows = list(workbook["2026-11"].iter_rows(values_only=True))

    assert [(row[0], row[6], row[7]) for row in rows[3:]] == [
        ("Total", 1500.4, "EUR"),
        ("Total", 1500.4, "USD"),
    ]


def test_empty_workbook_still_opens() -> None:
    workbook = load_workbook(BytesIO(build_workbook([])))
    assert workbook.sheetnames == ["Invoices"]


# Metrics


def test_metrics(session: Session) -> None:
    store(session, file_name="a.pdf", invoice_number="A")
    store(session, file_name="b.pdf", invoice_number="B", supplier="Cobalt Office")
    store(session, file_name="c.pdf", invoice_number="C", supplier="Cobalt Office")
    store(session, InvoiceStatus.NEEDS_REVIEW, file_name="d.pdf", issue_date=date(2026, 10, 30))
    store(session, InvoiceStatus.DUPLICATE, file_name="e.pdf")
    store(session, file_name="f.pdf", invoice_number="F", issue_date=date(2025, 12, 31))

    metrics = compute_metrics(InvoiceRepository(session).list_all(), TODAY)

    assert (metrics.invoices, metrics.ok, metrics.needs_review, metrics.duplicates) == (6, 4, 1, 1)
    assert metrics.invoices_this_month == 3
    assert metrics.spend_this_month == Decimal("4501.20")
    assert metrics.spend_last_month == Decimal("1500.40")
    assert [m.month for m in metrics.spend_by_month] == [
        date(2026, 6, 1),
        date(2026, 7, 1),
        date(2026, 8, 1),
        date(2026, 9, 1),
        date(2026, 10, 1),
        date(2026, 11, 1),
    ]
    assert [m.total for m in metrics.spend_by_month][-3:] == [
        Decimal("0"),
        Decimal("1500.40"),
        Decimal("4501.20"),
    ]
    assert metrics.suppliers == 2
    assert [(s.supplier, s.total) for s in metrics.top_suppliers] == [
        ("Cobalt Office", Decimal("3000.80")),
        ("Northlake Paper", Decimal("1500.40")),
    ]


def test_metrics_window_crosses_the_year(session: Session) -> None:
    metrics = compute_metrics([], date(2027, 2, 10), months=4)
    assert [m.month for m in metrics.spend_by_month] == [
        date(2026, 11, 1),
        date(2026, 12, 1),
        date(2027, 1, 1),
        date(2027, 2, 1),
    ]
