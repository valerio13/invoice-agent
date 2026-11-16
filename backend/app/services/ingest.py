"""Ingest: take the documents of a source, read each new one with the model and store it."""

from collections.abc import Callable
from datetime import date

from pydantic import BaseModel
from sqlalchemy.orm import Session

from app.db.repositories import InvoiceRepository
from app.domain.models import InvoiceFile, InvoiceStatus
from app.providers.llm.base import ExtractionError, LLMProvider
from app.providers.source.base import InvoiceSource
from app.services.checks import assess


class IngestResult(BaseModel):
    """What one run did."""

    # Invoices stored in this run, duplicates included.
    stored: int = 0
    # Documents that were already stored and were left alone.
    skipped: int = 0
    # File names the model could not read. Nothing is stored for them.
    failed: list[str] = []


class IngestService:
    """Reads the invoices a source offers and stores each one with its status."""

    def __init__(
        self,
        source: InvoiceSource,
        llm: LLMProvider,
        session: Session,
        today: Callable[[], date] = date.today,
    ) -> None:
        self._source = source
        self._llm = llm
        self._session = session
        self._repository = InvoiceRepository(session)
        self._today = today

    def run(self) -> IngestResult:
        """Process every document of the source. Running it twice stores nothing twice."""
        result = IngestResult()
        for file in self._source.fetch():
            outcome = self._process(file)
            if outcome == "stored":
                result.stored += 1
            elif outcome == "skipped":
                result.skipped += 1
            else:
                result.failed.append(file.file_name)
            # One commit per document, so a failure later does not lose the ones already read.
            self._session.commit()
        return result

    def _process(self, file: InvoiceFile) -> str:
        same_file = self._repository.find_by_hash(file.file_hash)
        if any(invoice.file_name == file.file_name for invoice in same_file):
            return "skipped"
        if same_file:
            # The same bytes under another name: its fields are known, so the model is not asked.
            original = same_file[0]
            self._repository.add(
                original.extraction(),
                file_name=file.file_name,
                file_hash=file.file_hash,
                status=InvoiceStatus.DUPLICATE,
                review_reasons=[f"Same file as {original.file_name}."],
            )
            return "stored"
        try:
            extraction = self._llm.extract(file)
        except ExtractionError:
            return "failed"
        status, reasons = assess(self._repository, extraction, self._today())
        self._repository.add(
            extraction,
            file_name=file.file_name,
            file_hash=file.file_hash,
            status=status,
            review_reasons=reasons,
        )
        return "stored"
