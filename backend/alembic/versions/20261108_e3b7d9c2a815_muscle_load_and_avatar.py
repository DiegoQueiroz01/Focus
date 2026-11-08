"""músculos trabalhados por sessão e foto de perfil

Revision ID: e3b7d9c2a815
Revises: c5e9a1f04d27
Create Date: 2026-11-08 20:00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op


revision: str = "e3b7d9c2a815"
down_revision: str | None = "c5e9a1f04d27"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("workout_sessions", sa.Column("muscle_load", sa.JSON(), nullable=True))
    op.add_column("users", sa.Column("avatar_url", sa.String(length=500), nullable=True))


def downgrade() -> None:
    op.drop_column("users", "avatar_url")
    op.drop_column("workout_sessions", "muscle_load")
