"""Demo: empty the database and load the fictitious invoices again, dated relative to today."""

from collections.abc import Callable
from datetime import date

from sqlalchemy.orm import Session

from app.db.repositories import InvoiceRepository
from app.providers.llm.fake import FakeLLMProvider
from app.providers.source.demo import DemoSource
from app.providers.storage import FileStore
from app.services.ingest import IngestResult, IngestService


def reload_demo(
    session: Session, files: FileStore, today: Callable[[], date] = date.today
) -> IngestResult:
    """Delete every invoice and ingest the demo set. Needs no key and no network."""
    InvoiceRepository(session).delete_all()
    service = IngestService(DemoSource(today), FakeLLMProvider(today), session, files, today)
    return service.run()
