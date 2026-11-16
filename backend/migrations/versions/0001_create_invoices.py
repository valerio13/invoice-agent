"""Create the invoices table.

Revision ID: 0001
Revises:
Create Date: 2026-11-16

"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "0001"
down_revision: str | Sequence[str] | None = None
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "invoices",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("file_name", sa.String(255), nullable=False),
        sa.Column("file_hash", sa.String(64), nullable=False),
        sa.Column("supplier", sa.String(200), nullable=False),
        sa.Column("invoice_number", sa.String(100), nullable=False),
        sa.Column("issue_date", sa.Date(), nullable=False),
        sa.Column("net_amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("vat_rate", sa.Numeric(5, 2), nullable=False),
        sa.Column("vat_amount", sa.Numeric(12, 2), nullable=False),
        sa.Column("total", sa.Numeric(12, 2), nullable=False),
        sa.Column("currency", sa.String(3), nullable=False),
        sa.Column("confidence", sa.Float(), nullable=False),
        sa.Column("status", sa.String(20), nullable=False),
        sa.Column("review_reasons", sa.JSON(), nullable=False),
        sa.Column("approved", sa.Boolean(), nullable=False),
        # CURRENT_TIMESTAMP and not now(), so the migration also runs on SQLite in the tests.
        sa.Column(
            "created_at",
            sa.DateTime(timezone=True),
            server_default=sa.text("CURRENT_TIMESTAMP"),
            nullable=False,
        ),
    )
    op.create_index("ix_invoices_file_hash", "invoices", ["file_hash"])
    op.create_index("ix_invoices_status", "invoices", ["status"])
    op.create_index("ix_invoices_supplier_number", "invoices", ["supplier", "invoice_number"])


def downgrade() -> None:
    op.drop_table("invoices")
