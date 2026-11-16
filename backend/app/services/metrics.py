"""Metrics: the figures of the Overview screen, computed from the stored invoices."""

from collections import defaultdict
from datetime import date
from decimal import Decimal

from pydantic import BaseModel

from app.domain.models import Invoice, InvoiceStatus


class MonthSpend(BaseModel):
    # First day of the month.
    month: date
    total: Decimal


class SupplierSpend(BaseModel):
    supplier: str
    total: Decimal


class Metrics(BaseModel):
    """Counts cover every stored invoice. Spend leaves duplicates out and assumes one currency."""

    invoices: int
    ok: int
    needs_review: int
    duplicates: int
    # Invoices dated in the current month, duplicates left out.
    invoices_this_month: int
    spend_this_month: Decimal
    spend_last_month: Decimal
    # Oldest month first, months without invoices included with zero.
    spend_by_month: list[MonthSpend]
    suppliers: int
    # Suppliers of the current month, largest spend first.
    top_suppliers: list[SupplierSpend]


def compute_metrics(invoices: list[Invoice], today: date, months: int = 6) -> Metrics:
    """Summarise the invoices as of `today`, with the spend of the last `months` months."""
    counted = [invoice for invoice in invoices if invoice.status != InvoiceStatus.DUPLICATE]
    this_month = today.replace(day=1)
    window = [_months_before(this_month, back) for back in range(months - 1, -1, -1)]

    by_month: dict[date, Decimal] = defaultdict(Decimal)
    by_supplier: dict[str, Decimal] = defaultdict(Decimal)
    for invoice in counted:
        month = invoice.issue_date.replace(day=1)
        by_month[month] += invoice.total
        if month == this_month:
            by_supplier[invoice.supplier] += invoice.total

    def count(status: InvoiceStatus) -> int:
        return sum(1 for invoice in invoices if invoice.status == status)

    return Metrics(
        invoices=len(invoices),
        ok=count(InvoiceStatus.OK),
        needs_review=count(InvoiceStatus.NEEDS_REVIEW),
        duplicates=count(InvoiceStatus.DUPLICATE),
        invoices_this_month=sum(
            1 for invoice in counted if invoice.issue_date.replace(day=1) == this_month
        ),
        spend_this_month=by_month[this_month],
        spend_last_month=by_month[_months_before(this_month, 1)],
        spend_by_month=[MonthSpend(month=month, total=by_month[month]) for month in window],
        suppliers=len({invoice.supplier for invoice in counted}),
        top_suppliers=[
            SupplierSpend(supplier=supplier, total=total)
            for supplier, total in sorted(by_supplier.items(), key=lambda item: (-item[1], item[0]))
        ],
    )


def _months_before(first_day: date, back: int) -> date:
    """Return the first day of the month `back` months before the given first day."""
    index = first_day.year * 12 + first_day.month - 1 - back
    return date(index // 12, index % 12 + 1, 1)
