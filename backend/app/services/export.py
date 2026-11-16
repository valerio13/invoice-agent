"""Export: build the Excel workbook from the stored invoices."""

from collections import defaultdict
from decimal import Decimal
from io import BytesIO

from openpyxl import Workbook
from openpyxl.styles import Alignment, Font, PatternFill
from openpyxl.worksheet.worksheet import Worksheet

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


def build_workbook(invoices: list[Invoice]) -> bytes:
    """Return an .xlsx file with one sheet per month, newest first, each with its totals.

    Only invoices with status ok are written: the ones waiting for review and the duplicates
    stay out until a human settles them.
    """
    by_month: dict[str, list[Invoice]] = defaultdict(list)
    for invoice in invoices:
        if invoice.status == InvoiceStatus.OK:
            by_month[invoice.issue_date.strftime("%Y-%m")].append(invoice)

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


def _write_month(sheet: Worksheet, invoices: list[Invoice]) -> None:
    # Totals are kept per currency: adding euros to dollars would mean nothing.
    totals: dict[str, list[Decimal]] = defaultdict(lambda: [Decimal("0")] * 3)
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
        amounts = (invoice.net_amount, invoice.vat_amount, invoice.total)
        totals[invoice.currency] = [
            a + b for a, b in zip(totals[invoice.currency], amounts, strict=True)
        ]

    for currency in sorted(totals):
        net, vat, total = totals[currency]
        sheet.append(["Total", None, None, net, None, vat, total, currency, None])
        _format_money(sheet, sheet.max_row)
        for cell in sheet[sheet.max_row]:
            cell.font = Font(bold=True)


def _format_money(sheet: Worksheet, row: int) -> None:
    for column in MONEY_COLUMNS:
        sheet.cell(row=row, column=column).number_format = MONEY_FORMAT
