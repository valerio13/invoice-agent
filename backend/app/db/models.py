"""Database models: the invoices table."""

from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import JSON, Boolean, DateTime, Index, Numeric, String, func
from sqlalchemy.orm import DeclarativeBase, Mapped, mapped_column


class Base(DeclarativeBase):
    """Base class for all database models."""

    # Every Mapped[datetime] column is stored timezone-aware.
    type_annotation_map = {datetime: DateTime(timezone=True)}


class InvoiceRecord(Base):
    """An invoice, as stored in the database."""

    __tablename__ = "invoices"
    # Not unique: a duplicate is stored too, with its own status, so the reviewer can see it.
    __table_args__ = (Index("ix_invoices_supplier_number", "supplier", "invoice_number"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    file_name: Mapped[str] = mapped_column(String(255))
    # SHA-256 of the file in hexadecimal.
    file_hash: Mapped[str] = mapped_column(String(64), index=True)
    supplier: Mapped[str] = mapped_column(String(200))
    invoice_number: Mapped[str] = mapped_column(String(100))
    issue_date: Mapped[date]
    net_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    vat_rate: Mapped[Decimal] = mapped_column(Numeric(5, 2))
    vat_amount: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    total: Mapped[Decimal] = mapped_column(Numeric(12, 2))
    currency: Mapped[str] = mapped_column(String(3))
    confidence: Mapped[float]
    status: Mapped[str] = mapped_column(String(20), index=True)
    review_reasons: Mapped[list[str]] = mapped_column(JSON, default=list)
    approved: Mapped[bool] = mapped_column(Boolean, default=False)
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())
