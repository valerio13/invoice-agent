"""REST endpoints. They only translate HTTP to service calls: the logic lives in the services."""

from datetime import date
from typing import Annotated

from fastapi import APIRouter, File, HTTPException, Query, UploadFile, status
from fastapi.responses import Response
from pydantic import BaseModel

from app import factory
from app.api.deps import FilesDep, LLMDep, SessionDep, SettingsDep, TodayDep
from app.db.repositories import InvoiceRepository
from app.domain.models import Extraction, Invoice, InvoiceStatus
from app.providers.source.limits import MAX_BYTES, media_type
from app.providers.source.upload import UploadSource
from app.services.checks import doubtful_fields
from app.services.demo import reload_demo
from app.services.export import build_workbook
from app.services.ingest import IngestResult, IngestService
from app.services.metrics import Metrics, compute_metrics
from app.services.preview import PreviewError, render_preview
from app.services.review import ReviewService

XLSX = "application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
NOT_FOUND = "Invoice not found."


class Health(BaseModel):
    status: str
    demo_mode: bool


class InvoiceView(Invoice):
    """A stored invoice as the API returns it, with the fields the reviewer should look at."""

    doubtful_fields: list[str]


def _view(invoice: Invoice, today: date) -> InvoiceView:
    fields = doubtful_fields(invoice, invoice.status, today) if not invoice.approved else []
    return InvoiceView(**invoice.model_dump(), doubtful_fields=fields)


class ReviewRequest(BaseModel):
    """The fields as the reviewer left them, and whether they vouch for them."""

    fields: Extraction
    approve: bool = False


class UploadResult(IngestResult):
    # Files that are not a PDF or an image, are empty or are larger than the limit.
    rejected: list[str] = []


system = APIRouter(tags=["system"])
invoices = APIRouter(prefix="/invoices", tags=["invoices"])
ingest = APIRouter(prefix="/ingest", tags=["ingest"])
reports = APIRouter(tags=["reports"])


@system.get("/health")
def health(settings: SettingsDep) -> Health:
    return Health(status="ok", demo_mode=settings.demo_mode)


@invoices.get("")
def list_invoices(
    session: SessionDep,
    today: TodayDep,
    status_filter: Annotated[InvoiceStatus | None, Query(alias="status")] = None,
) -> list[InvoiceView]:
    return [
        _view(invoice, today()) for invoice in InvoiceRepository(session).list_all(status_filter)
    ]


def _stored(invoice_id: int, session: SessionDep) -> Invoice:
    invoice = InvoiceRepository(session).get(invoice_id)
    if invoice is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, NOT_FOUND)
    return invoice


def _content(invoice: Invoice, files: FilesDep) -> bytes:
    content = files.load(invoice.file_hash)
    if content is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, "The document is no longer kept.")
    return content


@invoices.get("/{invoice_id}")
def get_invoice(invoice_id: int, session: SessionDep, today: TodayDep) -> InvoiceView:
    return _view(_stored(invoice_id, session), today())


@invoices.get("/{invoice_id}/document")
def get_document(invoice_id: int, session: SessionDep, files: FilesDep) -> Response:
    """The original document, as it arrived."""
    invoice = _stored(invoice_id, session)
    return Response(_content(invoice, files), media_type=media_type(invoice.file_name))


@invoices.get("/{invoice_id}/preview")
def get_preview(invoice_id: int, session: SessionDep, files: FilesDep) -> Response:
    """The first page as an image, to show it next to its fields. A PDF is drawn as PNG."""
    invoice = _stored(invoice_id, session)
    try:
        image, kind = render_preview(_content(invoice, files), invoice.file_name)
    except PreviewError as error:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_CONTENT, str(error)) from error
    return Response(image, media_type=kind)


@invoices.put("/{invoice_id}")
def review_invoice(
    invoice_id: int, request: ReviewRequest, session: SessionDep, today: TodayDep
) -> InvoiceView:
    invoice = ReviewService(session, today).save(
        invoice_id, request.fields, approve=request.approve
    )
    if invoice is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, NOT_FOUND)
    return _view(invoice, today())


@invoices.post("/{invoice_id}/duplicate")
def mark_duplicate(invoice_id: int, session: SessionDep, today: TodayDep) -> InvoiceView:
    invoice = ReviewService(session, today).mark_duplicate(invoice_id)
    if invoice is None:
        raise HTTPException(status.HTTP_404_NOT_FOUND, NOT_FOUND)
    return _view(invoice, today())


@ingest.post("/upload")
def upload(
    uploads: Annotated[list[UploadFile], File(alias="files")],
    session: SessionDep,
    llm: LLMDep,
    files: FilesDep,
    today: TodayDep,
) -> UploadResult:
    """Read the files dropped on the app."""
    # One byte over the limit is enough to know a file is too large, without reading it all.
    source = UploadSource(
        [(item.filename or "", item.file.read(MAX_BYTES + 1)) for item in uploads]
    )
    result = IngestService(source, llm, session, files, today).run()
    return UploadResult(**result.model_dump(), rejected=source.rejected)


@ingest.post("/folder")
def read_folder(
    settings: SettingsDep, session: SessionDep, llm: LLMDep, files: FilesDep, today: TodayDep
) -> IngestResult:
    """Read the new invoices of INVOICE_FOLDER."""
    source = factory.build_folder_source(settings)
    return IngestService(source, llm, session, files, today).run()


@ingest.post("/demo")
def load_demo(
    settings: SettingsDep, session: SessionDep, files: FilesDep, today: TodayDep
) -> IngestResult:
    """Replace every invoice with the demo set. Only in demo mode."""
    if not settings.demo_mode:
        raise HTTPException(status.HTTP_403_FORBIDDEN, "Demo mode is off.")
    return reload_demo(session, files, today)


@reports.get("/metrics")
def metrics(session: SessionDep, today: TodayDep) -> Metrics:
    return compute_metrics(InvoiceRepository(session).list_all(), today())


@reports.get("/export")
def export(session: SessionDep, today: TodayDep) -> Response:
    """The Excel workbook, rebuilt from the database on every request."""
    content = build_workbook(InvoiceRepository(session).list_all())
    name = f"invoices-{today().isoformat()}.xlsx"
    return Response(
        content, media_type=XLSX, headers={"Content-Disposition": f'attachment; filename="{name}"'}
    )
