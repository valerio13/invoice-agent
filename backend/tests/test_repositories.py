from datetime import date
from decimal import Decimal

from sqlalchemy.orm import Session

from app.db.repositories import InvoiceRepository
from app.domain.models import Invoice, InvoiceStatus
from tests.helpers import make_extraction


def add(repo: InvoiceRepository, file_hash: str = "a" * 64, **changes: object) -> Invoice:
    return repo.add(
        make_extraction(**changes),
        file_name="invoice.pdf",
        file_hash=file_hash,
        status=InvoiceStatus.OK,
        review_reasons=[],
    )


def test_an_invoice_is_stored_and_read_back_exactly(session: Session) -> None:
    repo = InvoiceRepository(session)
    stored = add(repo)
    read = repo.get(stored.id)
    assert read is not None
    assert read.total == Decimal("1500.40")
    assert read.issue_date == date(2026, 11, 12)
    assert read.status is InvoiceStatus.OK
    assert read.approved is False
    assert read.created_at is not None


def test_an_unknown_invoice_is_none(session: Session) -> None:
    assert InvoiceRepository(session).get(999) is None


def test_list_is_newest_first_and_filters_by_status(session: Session) -> None:
    repo = InvoiceRepository(session)
    add(repo, invoice_number="OLD", issue_date=date(2026, 10, 1))
    add(repo, invoice_number="NEW", issue_date=date(2026, 11, 20))
    repo.add(
        make_extraction(invoice_number="DOUBT"),
        file_name="doubt.pdf",
        file_hash="b" * 64,
        status=InvoiceStatus.NEEDS_REVIEW,
        review_reasons=["Net plus VAT does not equal the total."],
    )
    assert [invoice.invoice_number for invoice in repo.list_all()] == ["NEW", "DOUBT", "OLD"]
    doubtful = repo.list_all(InvoiceStatus.NEEDS_REVIEW)
    assert [invoice.invoice_number for invoice in doubtful] == ["DOUBT"]
    assert doubtful[0].review_reasons == ["Net plus VAT does not equal the total."]


def test_the_same_file_is_recognised_by_its_hash(session: Session) -> None:
    repo = InvoiceRepository(session)
    add(repo, file_hash="c" * 64)
    assert repo.has_file("c" * 64)
    assert not repo.has_file("d" * 64)


def test_the_same_number_of_a_supplier_is_found_ignoring_case(session: Session) -> None:
    repo = InvoiceRepository(session)
    add(repo)
    assert len(repo.find_same_number("NORTHLAKE PAPER", "inv-2026-0412")) == 1
    assert repo.find_same_number("Another supplier", "INV-2026-0412") == []


def test_a_review_replaces_the_fields(session: Session) -> None:
    repo = InvoiceRepository(session)
    stored = add(repo, total=Decimal("1510.40"))
    updated = repo.update(
        stored.id,
        make_extraction(),
        status=InvoiceStatus.OK,
        review_reasons=[],
        approved=True,
    )
    assert updated is not None
    assert updated.total == Decimal("1500.40")
    assert updated.approved is True
    assert (
        repo.update(
            999, make_extraction(), status=InvoiceStatus.OK, review_reasons=[], approved=True
        )
        is None
    )


def test_delete_all_empties_the_table(session: Session) -> None:
    repo = InvoiceRepository(session)
    add(repo)
    repo.delete_all()
    assert repo.list_all() == []
