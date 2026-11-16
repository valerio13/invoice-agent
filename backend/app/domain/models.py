"""Domain models shared by every layer: the fields read from an invoice and the stored invoice."""

import hashlib
from datetime import date, datetime
from decimal import Decimal
from enum import StrEnum

from pydantic import BaseModel, ConfigDict, Field

# Largest difference accepted between net amount plus VAT and the total, to allow for rounding.
AMOUNT_TOLERANCE = Decimal("0.01")


class InvoiceStatus(StrEnum):
    OK = "ok"
    NEEDS_REVIEW = "needs_review"
    DUPLICATE = "duplicate"


class InvoiceFile(BaseModel):
    """An invoice document as it arrives from a source: its name and its bytes."""

    model_config = ConfigDict(frozen=True)

    file_name: str
    content: bytes = Field(repr=False)

    @property
    def file_hash(self) -> str:
        """SHA-256 of the content, to spot the same document arriving twice."""
        return hashlib.sha256(self.content).hexdigest()


class Extraction(BaseModel):
    """The fields of one invoice, as returned by the LLM."""

    model_config = ConfigDict(str_strip_whitespace=True, from_attributes=True)

    supplier: str = Field(min_length=1, max_length=200, description="Name of the company issuing.")
    invoice_number: str = Field(min_length=1, max_length=100, description="Number of the invoice.")
    issue_date: date = Field(description="Date the invoice was issued.")
    net_amount: Decimal = Field(ge=0, decimal_places=2, description="Amount before VAT.")
    vat_rate: Decimal = Field(ge=0, le=100, description="VAT rate as a percentage, such as 21.")
    vat_amount: Decimal = Field(ge=0, decimal_places=2, description="Amount of VAT.")
    total: Decimal = Field(ge=0, decimal_places=2, description="Total to pay, VAT included.")
    currency: str = Field(pattern=r"^[A-Z]{3}$", description="ISO 4217 code, such as EUR.")
    confidence: float = Field(ge=0, le=1, description="How sure the reading is, from 0 to 1.")

    def amounts_add_up(self) -> bool:
        """True if net amount plus VAT equals the total. Checked in code, never asked to the LLM."""
        return abs(self.net_amount + self.vat_amount - self.total) <= AMOUNT_TOLERANCE


class Invoice(Extraction):
    """A stored invoice: its file, the extracted fields and where it stands."""

    id: int
    file_name: str
    # SHA-256 of the file, to spot the same document arriving twice.
    file_hash: str
    status: InvoiceStatus
    # Why it needs review, in plain words. Empty when the status is ok.
    review_reasons: list[str] = []
    approved: bool = False
    created_at: datetime
