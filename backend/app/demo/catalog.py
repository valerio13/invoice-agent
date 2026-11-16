"""The demo invoices: fictitious data read from demo/invoices.json and dated relative to today."""

import json
from datetime import date, timedelta
from decimal import ROUND_HALF_UP, Decimal
from pathlib import Path

from pydantic import BaseModel, ConfigDict

from app.domain.models import Extraction

# catalog.py -> demo -> app -> backend -> project root
DEMO_FILE = Path(__file__).resolve().parents[3] / "demo" / "invoices.json"
CENT = Decimal("0.01")
# How sure a model would be reading a clean PDF and a scanned one.
CONFIDENCE_CLEAN = 0.96
CONFIDENCE_SCANNED = 0.58


class DemoInvoice(BaseModel):
    """One fictitious invoice, with everything needed to draw it and to know what it says."""

    model_config = ConfigDict(frozen=True)

    file_name: str
    supplier: str
    address: str
    color: tuple[int, int, int]
    number: str
    issue_date: date
    lines: tuple[tuple[str, Decimal], ...]
    vat_rate: Decimal
    # Added to the printed total on purpose, so that it does not add up. Zero on a correct invoice.
    total_offset: Decimal = Decimal("0")
    scanned: bool = False
    note: str = ""
    # Name of the invoice this file is a byte-for-byte copy of, if any.
    copy_of: str | None = None

    @property
    def net_amount(self) -> Decimal:
        return sum((amount for _, amount in self.lines), Decimal("0"))

    @property
    def vat_amount(self) -> Decimal:
        return (self.net_amount * self.vat_rate / 100).quantize(CENT, ROUND_HALF_UP)

    @property
    def printed_total(self) -> Decimal:
        return self.net_amount + self.vat_amount + self.total_offset

    def expected_extraction(self) -> Extraction:
        """What a careful reader gets from the document, including a total that is wrong on it."""
        return Extraction(
            supplier=self.supplier,
            invoice_number=self.number,
            issue_date=self.issue_date,
            net_amount=self.net_amount,
            vat_rate=self.vat_rate,
            vat_amount=self.vat_amount,
            total=self.printed_total,
            currency="EUR",
            confidence=CONFIDENCE_SCANNED if self.scanned else CONFIDENCE_CLEAN,
        )


def load_demo_invoices(today: date, path: Path = DEMO_FILE) -> list[DemoInvoice]:
    """Return the demo invoices, newest first, with dates counted back from today."""
    data = json.loads(path.read_text(encoding="utf-8"))
    suppliers = data["suppliers"]
    invoices: dict[str, DemoInvoice] = {}
    for entry in data["invoices"]:
        if "copy_of" in entry:
            original = invoices[entry["copy_of"]]
            invoice = original.model_copy(
                update={"file_name": entry["file"], "copy_of": original.file_name}
            )
        else:
            supplier = suppliers[entry["supplier"]]
            invoice = DemoInvoice(
                file_name=entry["file"],
                supplier=supplier["name"],
                address=supplier["address"],
                color=supplier["color"],
                number=entry["number"],
                issue_date=today - timedelta(days=entry["days_ago"]),
                lines=entry["lines"],
                vat_rate=supplier["vat"],
                total_offset=entry.get("total_offset", "0"),
                scanned=entry.get("scanned", False),
                note=entry.get("note", ""),
            )
        invoices[invoice.file_name] = invoice
    return sorted(invoices.values(), key=lambda invoice: invoice.issue_date, reverse=True)
