"""Draws a demo invoice as a one-page PDF."""

from datetime import UTC, datetime

from fpdf import FPDF
from fpdf.enums import XPos, YPos

from app.demo.catalog import DemoInvoice

BUYER = ("Demo Company Ltd", "1 Example Avenue, Sample City")
INK = (45, 55, 55)
MUTED = (125, 135, 135)


def render_invoice(invoice: DemoInvoice) -> bytes:
    """Return the PDF of the invoice. The same invoice always gives the same bytes."""
    pdf = FPDF(format="A4")
    # A fixed date keeps the file identical between runs, so its hash is stable within a day.
    pdf.set_creation_date(datetime(2026, 1, 1, tzinfo=UTC))
    pdf.set_margins(20, 20, 20)
    pdf.add_page()
    if invoice.scanned:
        # A scan: a grey sheet, slightly turned.
        pdf.set_fill_color(236, 234, 228)
        pdf.rect(0, 0, 210, 297, style="F")
        with pdf.rotation(1.6, x=105, y=148):
            _draw(pdf, invoice)
    else:
        _draw(pdf, invoice)
    return bytes(pdf.output())


def _draw(pdf: FPDF, invoice: DemoInvoice) -> None:
    next_line = {"new_x": XPos.LMARGIN, "new_y": YPos.NEXT}

    pdf.set_fill_color(*invoice.color)
    pdf.rect(20, 20, 6, 22, style="F")
    pdf.set_xy(30, 20)
    pdf.set_text_color(*INK)
    pdf.set_font("Helvetica", "B", 16)
    pdf.cell(100, 9, invoice.supplier)
    pdf.set_font("Helvetica", "B", 22)
    pdf.set_text_color(*invoice.color)
    pdf.cell(0, 9, "INVOICE", align="R", **next_line)
    pdf.set_x(30)
    pdf.set_font("Helvetica", "", 9)
    pdf.set_text_color(*MUTED)
    pdf.cell(0, 6, invoice.address, **next_line)

    pdf.set_y(58)
    for label, value in (
        ("Invoice number", invoice.number),
        ("Date", invoice.issue_date.strftime("%d %B %Y")),
        ("Billed to", f"{BUYER[0]}, {BUYER[1]}"),
    ):
        pdf.set_font("Helvetica", "B", 8)
        pdf.set_text_color(*MUTED)
        pdf.cell(38, 7, label.upper())
        pdf.set_font("Helvetica", "", 10)
        pdf.set_text_color(*INK)
        pdf.cell(0, 7, value, **next_line)

    pdf.set_y(92)
    pdf.set_font("Helvetica", "B", 8)
    pdf.set_text_color(*MUTED)
    pdf.cell(130, 8, "DESCRIPTION")
    pdf.cell(0, 8, "AMOUNT (EUR)", align="R", **next_line)
    pdf.set_draw_color(*invoice.color)
    pdf.set_line_width(0.5)
    pdf.line(20, pdf.get_y(), 190, pdf.get_y())
    pdf.set_font("Helvetica", "", 10)
    pdf.set_text_color(*INK)
    pdf.set_draw_color(220, 226, 226)
    pdf.set_line_width(0.2)
    for description, amount in invoice.lines:
        pdf.cell(130, 10, description)
        pdf.cell(0, 10, f"{amount:,.2f}", align="R", **next_line)
        pdf.line(20, pdf.get_y(), 190, pdf.get_y())

    pdf.ln(8)
    for label, value, bold in (
        ("Net amount", invoice.net_amount, False),
        (f"VAT {invoice.vat_rate:g}%", invoice.vat_amount, False),
        ("Total EUR", invoice.printed_total, True),
    ):
        pdf.set_x(120)
        pdf.set_font("Helvetica", "B" if bold else "", 12 if bold else 10)
        pdf.cell(35, 8, label)
        pdf.cell(0, 8, f"{value:,.2f}", align="R", **next_line)

    pdf.set_y(250)
    pdf.set_font("Helvetica", "", 8)
    pdf.set_text_color(*MUTED)
    if invoice.note:
        pdf.cell(0, 5, invoice.note, **next_line)
    pdf.cell(0, 5, "Payment within 30 days. Fictitious invoice made for a demo.", **next_line)
