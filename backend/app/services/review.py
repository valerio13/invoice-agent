"""Review: what the human does with an invoice (correct it, approve it, call it a duplicate)."""

from collections.abc import Callable
from datetime import date

from sqlalchemy.orm import Session

from app.db.repositories import InvoiceRepository
from app.domain.models import Extraction, Invoice, InvoiceStatus
from app.services.checks import assess

MARKED_DUPLICATE = "Marked as a duplicate by the reviewer."


class ReviewService:
    """Applies the decisions of the reviewer. Every method returns None if the invoice is gone."""

    def __init__(self, session: Session, today: Callable[[], date] = date.today) -> None:
        self._session = session
        self._repository = InvoiceRepository(session)
        self._today = today

    def save(self, invoice_id: int, fields: Extraction, *, approve: bool) -> Invoice | None:
        """Store the corrected fields.

        With `approve` the human vouches for them: the invoice becomes ok whatever the checks
        say. Without it the checks run again on the new fields and decide the status.
        """
        if approve:
            status, reasons = InvoiceStatus.OK, []
        else:
            status, reasons = assess(self._repository, fields, self._today(), invoice_id)
        invoice = self._repository.update(
            invoice_id, fields, status=status, review_reasons=reasons, approved=approve
        )
        self._session.commit()
        return invoice

    def mark_duplicate(self, invoice_id: int) -> Invoice | None:
        """Set the invoice aside as a duplicate, so it stays out of the workbook."""
        current = self._repository.get(invoice_id)
        if current is None:
            return None
        invoice = self._repository.update(
            invoice_id,
            current.extraction(),
            status=InvoiceStatus.DUPLICATE,
            review_reasons=[MARKED_DUPLICATE],
            approved=False,
        )
        self._session.commit()
        return invoice
