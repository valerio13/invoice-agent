"""Export: build the Excel workbook from the stored invoices."""

from collections import defaultdict
from datetime import date
from decimal import Decimal
from io import BytesIO

from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.worksheet.worksheet import Worksheet
from pydantic import BaseModel

from app.domain.models import Invoice, InvoiceStatus

HEADERS = [
    "Date",
    "Supplier",
    "Invoice number",
    "Net amount",
    "VAT %",
    "VAT amount",
    "Total",
    "Currency",
    "File",
]
WIDTHS = [12, 30, 20, 14, 8, 14, 14, 10, 36]
# Columns holding money (1-based), formatted with two decimals.
MONEY_COLUMNS = (4, 6, 7)
MONEY_FORMAT = "#,##0.00"
HEADER_FILL = PatternFill("solid", fgColor="425C5B")
HEADER_FONT = Font(bold=True, color="FFFFFF")
EMPTY_SHEET = "Invoices"


class CurrencyTotal(BaseModel):
    currency: str
    net_amount: Decimal
    vat_amount: Decimal
    total: Decimal


class SheetSummary(BaseModel):
    """One sheet of the workbook: a month of ok invoices."""

    name: str
    # First day of the month.
    month: date
    invoices: int
    # One line per currency, as at the end of the sheet.
    totals: list[CurrencyTotal]


class ExportSummary(BaseModel):
    """What the workbook will hold, to show it before saving."""

    file_name: str
    sheets: list[SheetSummary]
    # Invoices that stay out of the workbook until a human settles them.
    needs_review: int
    duplicates: int


def workbook_name(today: date) -> str:
    return f"invoices-{today.isoformat()}.xlsx"


def summarize(invoices: list[Invoice], today: date) -> ExportSummary:
    by_month = _by_month(invoices)
    return ExportSummary(
        file_name=workbook_name(today),
        sheets=[
            SheetSummary(
                name=month,
                month=date.fromisoformat(f"{month}-01"),
                invoices=len(by_month[month]),
                totals=_totals(by_month[month]),
            )
            for month in sorted(by_month, reverse=True)
        ],
        needs_review=sum(invoice.status == InvoiceStatus.NEEDS_REVIEW for invoice in invoices),
        duplicates=sum(invoice.status == InvoiceStatus.DUPLICATE for invoice in invoices),
    )


def build_workbook(invoices: list[Invoice]) -> bytes:
    """Return an .xlsx file with one sheet per month, newest first, each with its totals.

    Only invoices with status ok are written: the ones waiting for review and the duplicates
    stay out until a human settles them.
    """
    by_month = _by_month(invoices)

    workbook = Workbook()
    first = workbook.active
    if not by_month:
        first.title = EMPTY_SHEET
        _write_header(first)
    for position, month in enumerate(sorted(by_month, reverse=True)):
        sheet = first if position == 0 else workbook.create_sheet()
        sheet.title = month
        _write_header(sheet)
        _write_month(sheet, by_month[month])

    buffer = BytesIO()
    workbook.save(buffer)
    return buffer.getvalue()


def _write_header(sheet: Worksheet) -> None:
    sheet.append(HEADERS)
    for column, width in enumerate(WIDTHS, start=1):
        cell = sheet.cell(row=1, column=column)
        cell.font = HEADER_FONT
        cell.fill = HEADER_FILL
        cell.alignment = Alignment(horizontal="left")
        sheet.column_dimensions[cell.column_letter].width = width
    sheet.freeze_panes = "A2"


def _by_month(invoices: list[Invoice]) -> dict[str, list[Invoice]]:
    """The ok invoices, by month as "YYYY-MM"."""
    by_month: dict[str, list[Invoice]] = defaultdict(list)
    for invoice in invoices:
        if invoice.status == InvoiceStatus.OK:
            by_month[invoice.issue_date.strftime("%Y-%m")].append(invoice)
    return by_month


def _totals(invoices: list[Invoice]) -> list[CurrencyTotal]:
    # Totals are kept per currency: adding euros to dollars would mean nothing.
    totals: dict[str, list[Decimal]] = defaultdict(lambda: [Decimal("0")] * 3)
    for invoice in invoices:
        amounts = (invoice.net_amount, invoice.vat_amount, invoice.total)
        totals[invoice.currency] = [
            a + b for a, b in zip(totals[invoice.currency], amounts, strict=True)
        ]
    return [
        CurrencyTotal(currency=currency, net_amount=net, vat_amount=vat, total=total)
        for currency, (net, vat, total) in sorted(totals.items())
    ]


def _write_month(sheet: Worksheet, invoices: list[Invoice]) -> None:
    for invoice in sorted(invoices, key=lambda item: (item.issue_date, item.supplier, item.id)):
        sheet.append(
            [
                invoice.issue_date,
                invoice.supplier,
                invoice.invoice_number,
                invoice.net_amount,
                invoice.vat_rate,
                invoice.vat_amount,
                invoice.total,
                invoice.currency,
                invoice.file_name,
            ]
        )
        sheet.cell(row=sheet.max_row, column=1).number_format = "yyyy-mm-dd"
        _format_money(sheet, sheet.max_row)

    for line in _totals(invoices):
        net, vat, total = line.net_amount, line.vat_amount, line.total
        sheet.append(["Total", None, None, net, None, vat, total, line.currency, None])
        _format_money(sheet, sheet.max_row)
        for cell in sheet[sheet.max_row]:
            cell.font = Font(bold=True)


def _format_money(sheet: Worksheet, row: int) -> None:
    for column in MONEY_COLUMNS:
        sheet.cell(row=row, column=column).number_format = MONEY_FORMAT
