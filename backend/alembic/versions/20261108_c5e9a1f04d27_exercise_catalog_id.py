"""vínculo do exercício com o catálogo

Revision ID: c5e9a1f04d27
Revises: 8c41d2e7a9b3
Create Date: 2026-11-08 18:00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op


revision: str = "c5e9a1f04d27"
down_revision: str | None = "8c41d2e7a9b3"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("exercises", sa.Column("catalog_id", sa.String(length=100), nullable=True))


def downgrade() -> None:
    op.drop_column("exercises", "catalog_id")
