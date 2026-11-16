"""Invoice source for demo mode: fictitious invoices drawn on the spot."""

from collections.abc import Callable
from datetime import date

from app.demo.catalog import load_demo_invoices
from app.demo.render import render_invoice
from app.domain.models import InvoiceFile
from app.providers.source.base import InvoiceSource


class DemoSource(InvoiceSource):
    """Draws the demo invoices with dates counted back from today, so the demo never looks stale."""

    def __init__(self, today: Callable[[], date] = date.today) -> None:
        self._today = today

    def fetch(self) -> list[InvoiceFile]:
        invoices = load_demo_invoices(self._today())
        # Originals first, so the bytes of a copy already exist when its turn comes.
        rendered = {
            invoice.file_name: render_invoice(invoice)
            for invoice in invoices
            if invoice.copy_of is None
        }
        return [
            InvoiceFile(
                file_name=invoice.file_name,
                content=rendered[invoice.copy_of or invoice.file_name],
            )
            for invoice in invoices
        ]
