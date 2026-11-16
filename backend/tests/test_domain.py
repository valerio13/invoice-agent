from decimal import Decimal

import pytest
from pydantic import ValidationError

from tests.helpers import make_extraction


def test_amounts_add_up() -> None:
    assert make_extraction().amounts_add_up()


def test_a_cent_of_rounding_is_accepted() -> None:
    assert make_extraction(total=Decimal("1500.41")).amounts_add_up()


def test_a_wrong_total_does_not_add_up() -> None:
    assert not make_extraction(total=Decimal("1510.40")).amounts_add_up()


def test_text_is_read_as_a_decimal_without_float_errors() -> None:
    extraction = make_extraction(net_amount="0.10", vat_amount="0.20", total="0.30")
    assert extraction.amounts_add_up()
    assert extraction.total == Decimal("0.30")


@pytest.mark.parametrize(
    "changes",
    [
        {"supplier": "   "},
        {"total": Decimal("-1.00")},
        {"total": "not a number"},
        {"currency": "euros"},
        {"confidence": 1.5},
        {"issue_date": "yesterday"},
    ],
)
def test_invalid_fields_are_rejected(changes: dict[str, object]) -> None:
    with pytest.raises(ValidationError):
        make_extraction(**changes)
