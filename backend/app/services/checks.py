"""Checks made in code on what the model read: arithmetic, confidence, dates and duplicates.

Nothing here asks the model anything. The result decides the status of an invoice.
"""

from datetime import date
from decimal import ROUND_HALF_UP, Decimal

from app.db.repositories import InvoiceRepository
from app.domain.models import AMOUNT_TOLERANCE, Extraction, InvoiceStatus

# Below this confidence a human looks at the invoice, even if everything else is fine.
MIN_CONFIDENCE = 0.8
CENT = Decimal("0.01")


def review_reasons(extraction: Extraction, today: date) -> list[str]:
    """Return why a human should look at this invoice, in plain words. Empty if nothing is odd."""
    reasons = []
    if not extraction.amounts_add_up():
        expected = extraction.net_amount + extraction.vat_amount
        reasons.append(
            f"Net amount plus VAT is {expected:.2f}, but the total says {extraction.total:.2f}."
        )
    expected_vat = (extraction.net_amount * extraction.vat_rate / 100).quantize(CENT, ROUND_HALF_UP)
    if abs(expected_vat - extraction.vat_amount) > AMOUNT_TOLERANCE:
        reasons.append(
            f"VAT at {extraction.vat_rate.normalize():f}% should be {expected_vat:.2f}, "
            f"but the invoice says {extraction.vat_amount:.2f}."
        )
    if extraction.confidence < MIN_CONFIDENCE:
        reasons.append(f"The reading is not reliable (confidence {extraction.confidence:.0%}).")
    if extraction.issue_date > today:
        reasons.append("The issue date is in the future.")
    return reasons


def duplicate_reason(
    repository: InvoiceRepository, extraction: Extraction, exclude_id: int | None = None
) -> str | None:
    """Return why this invoice repeats a stored one (same supplier and number), or None.

    Invoices already stored as duplicates do not count, and neither does the invoice itself
    (`exclude_id`) when it is checked again after a correction.
    """
    for other in repository.find_same_number(extraction.supplier, extraction.invoice_number):
        if other.id != exclude_id and other.status != InvoiceStatus.DUPLICATE:
            return f"Same supplier and invoice number as {other.file_name}."
    return None


def assess(
    repository: InvoiceRepository,
    extraction: Extraction,
    today: date,
    exclude_id: int | None = None,
) -> tuple[InvoiceStatus, list[str]]:
    """Run every check and return the status of the invoice with the reasons behind it."""
    reasons = review_reasons(extraction, today)
    repeated = duplicate_reason(repository, extraction, exclude_id)
    if repeated:
        return InvoiceStatus.DUPLICATE, [repeated, *reasons]
    if reasons:
        return InvoiceStatus.NEEDS_REVIEW, reasons
    return InvoiceStatus.OK, []
