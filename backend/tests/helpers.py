from datetime import date
from decimal import Decimal

from app.domain.models import Extraction


def make_extraction(**changes: object) -> Extraction:
    """A valid extraction, with any field replaced by the given value."""
    fields: dict[str, object] = {
        "supplier": "Northlake Paper",
        "invoice_number": "INV-2026-0412",
        "issue_date": date(2026, 11, 12),
        "net_amount": Decimal("1240.00"),
        "vat_rate": Decimal("21"),
        "vat_amount": Decimal("260.40"),
        "total": Decimal("1500.40"),
        "currency": "EUR",
        "confidence": 0.97,
    }
    return Extraction(**(fields | changes))
