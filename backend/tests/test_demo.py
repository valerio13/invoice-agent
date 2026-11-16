from datetime import date
from decimal import Decimal

from app.demo.catalog import load_demo_invoices
from app.demo.render import render_invoice
from app.providers.llm.fake import FakeLLMProvider
from app.providers.source.demo import DemoSource

TODAY = date(2026, 11, 16)


def test_the_demo_set_has_every_case_the_demo_shows() -> None:
    invoices = load_demo_invoices(TODAY)
    assert len(invoices) == 38
    assert sum(1 for invoice in invoices if invoice.total_offset != 0) == 3
    assert sum(1 for invoice in invoices if invoice.scanned) == 2
    assert sum(1 for invoice in invoices if invoice.copy_of) == 1
    # One invoice sent twice as different files: same supplier and number.
    keys = [(invoice.supplier, invoice.number) for invoice in invoices if not invoice.copy_of]
    assert len(keys) - len(set(keys)) == 1


def test_dates_follow_today_and_never_come_from_the_future() -> None:
    invoices = load_demo_invoices(TODAY)
    assert max(invoice.issue_date for invoice in invoices) <= TODAY
    later = load_demo_invoices(date(2027, 3, 1))
    assert max(invoice.issue_date for invoice in later) > TODAY


def test_a_correct_invoice_adds_up_and_a_flawed_one_does_not() -> None:
    for invoice in load_demo_invoices(TODAY):
        extraction = invoice.expected_extraction()
        assert extraction.amounts_add_up() == (invoice.total_offset == Decimal("0"))


def test_a_scanned_invoice_is_read_with_less_confidence() -> None:
    invoices = load_demo_invoices(TODAY)
    scanned = next(invoice for invoice in invoices if invoice.scanned)
    clean = next(invoice for invoice in invoices if not invoice.scanned)
    assert scanned.expected_extraction().confidence < clean.expected_extraction().confidence


def test_an_invoice_is_drawn_as_a_pdf_and_always_gives_the_same_bytes() -> None:
    invoice = load_demo_invoices(TODAY)[0]
    pdf = render_invoice(invoice)
    assert pdf.startswith(b"%PDF")
    assert pdf == render_invoice(invoice)


def test_the_demo_source_gives_every_invoice_and_the_copy_is_identical() -> None:
    files = DemoSource(today=lambda: TODAY).fetch()
    assert len(files) == 38
    assert len({file.file_name for file in files}) == 38
    # 38 files but 37 different documents: one is a byte-for-byte copy.
    assert len({file.file_hash for file in files}) == 37


def test_the_fake_model_reads_every_demo_invoice() -> None:
    model = FakeLLMProvider(today=lambda: TODAY)
    for file in DemoSource(today=lambda: TODAY).fetch():
        assert model.extract(file).currency == "EUR"
