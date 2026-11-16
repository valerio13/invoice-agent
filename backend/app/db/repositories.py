"""Repositories: save and read domain models so services never deal with SQL or tables.

Repositories never commit. The caller (a service) decides when to commit or roll back.
"""

from sqlalchemy import delete, func, select
from sqlalchemy.orm import Session

from app.db.models import InvoiceRecord
from app.domain.models import Extraction, Invoice, InvoiceStatus


class InvoiceRepository:
    """Stores and reads invoices."""

    def __init__(self, session: Session) -> None:
        self._session = session

    def add(
        self,
        extraction: Extraction,
        *,
        file_name: str,
        file_hash: str,
        status: InvoiceStatus,
        review_reasons: list[str],
    ) -> Invoice:
        """Store a new invoice and return it with its id."""
        record = InvoiceRecord(
            **extraction.model_dump(),
            file_name=file_name,
            file_hash=file_hash,
            status=status,
            review_reasons=review_reasons,
        )
        self._session.add(record)
        # flush sends the INSERT now, so the id exists and later checks see this invoice.
        self._session.flush()
        self._session.refresh(record)
        return Invoice.model_validate(record)

    def get(self, invoice_id: int) -> Invoice | None:
        """Return the invoice with this id, or None."""
        record = self._session.get(InvoiceRecord, invoice_id)
        return Invoice.model_validate(record) if record else None

    def list_all(self, status: InvoiceStatus | None = None) -> list[Invoice]:
        """Return the invoices, newest issue date first, optionally of one status."""
        stmt = select(InvoiceRecord).order_by(InvoiceRecord.issue_date.desc(), InvoiceRecord.id)
        if status is not None:
            stmt = stmt.where(InvoiceRecord.status == status)
        return [Invoice.model_validate(record) for record in self._session.scalars(stmt)]

    def has_file(self, file_hash: str) -> bool:
        """True if a file with this hash was already stored."""
        stmt = select(InvoiceRecord.id).where(InvoiceRecord.file_hash == file_hash).limit(1)
        return self._session.scalar(stmt) is not None

    def find_same_number(self, supplier: str, invoice_number: str) -> list[Invoice]:
        """Return the stored invoices of this supplier with this number, ignoring case."""
        stmt = select(InvoiceRecord).where(
            func.lower(InvoiceRecord.supplier) == supplier.lower(),
            func.lower(InvoiceRecord.invoice_number) == invoice_number.lower(),
        )
        return [Invoice.model_validate(record) for record in self._session.scalars(stmt)]

    def update(
        self,
        invoice_id: int,
        extraction: Extraction,
        *,
        status: InvoiceStatus,
        review_reasons: list[str],
        approved: bool,
    ) -> Invoice | None:
        """Replace the fields of an invoice after a review. Return None if it does not exist."""
        record = self._session.get(InvoiceRecord, invoice_id)
        if record is None:
            return None
        for name, value in extraction.model_dump().items():
            setattr(record, name, value)
        record.status = status
        record.review_reasons = review_reasons
        record.approved = approved
        self._session.flush()
        return Invoice.model_validate(record)

    def delete_all(self) -> None:
        """Delete every invoice."""
        self._session.execute(delete(InvoiceRecord))
        self._session.flush()
