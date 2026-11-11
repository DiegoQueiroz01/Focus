"""relógio: resumo diário vindo do Health Connect

Revision ID: b9e4f2a6d1c3
Revises: a7d3e5f1c2b8
Create Date: 2026-11-10 10:00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op


revision: str = "b9e4f2a6d1c3"
down_revision: str | None = "a7d3e5f1c2b8"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "health_days",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("steps", sa.Integer(), nullable=True),
        sa.Column("distance_m", sa.Float(), nullable=True),
        sa.Column("active_calories", sa.Integer(), nullable=True),
        sa.Column("resting_hr", sa.Integer(), nullable=True),
        sa.Column("avg_hr", sa.Integer(), nullable=True),
        sa.Column("min_hr", sa.Integer(), nullable=True),
        sa.Column("max_hr", sa.Integer(), nullable=True),
        sa.Column("heart_rate_series", sa.JSON(), nullable=True),
        sa.Column("sleep_minutes", sa.Integer(), nullable=True),
        sa.Column("sleep_deep_minutes", sa.Integer(), nullable=True),
        sa.Column("sleep_light_minutes", sa.Integer(), nullable=True),
        sa.Column("sleep_rem_minutes", sa.Integer(), nullable=True),
        sa.Column("sleep_awake_minutes", sa.Integer(), nullable=True),
        sa.Column("sleep_start", sa.DateTime(timezone=True), nullable=True),
        sa.Column("sleep_end", sa.DateTime(timezone=True), nullable=True),
        sa.Column("spo2_avg", sa.Float(), nullable=True),
        sa.Column("spo2_min", sa.Float(), nullable=True),
        sa.Column("synced_at", sa.DateTime(timezone=True), nullable=False),
        sa.UniqueConstraint("user_id", "date", name="uq_health_days_user_date"),
    )
    op.create_index("ix_health_days_user_id", "health_days", ["user_id"])


def downgrade() -> None:
    op.drop_index("ix_health_days_user_id", table_name="health_days")
    op.drop_table("health_days")
