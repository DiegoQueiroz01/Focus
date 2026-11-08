"""atividades gravadas por GPS

Revision ID: f4a2c8e1b9d6
Revises: e3b7d9c2a815
Create Date: 2026-11-08 22:00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op


revision: str = "f4a2c8e1b9d6"
down_revision: str | None = "e3b7d9c2a815"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.create_table(
        "gps_activities",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("activity_type", sa.String(length=30), nullable=False),
        sa.Column("started_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("finished_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("elapsed_seconds", sa.Integer(), nullable=False),
        sa.Column("moving_seconds", sa.Integer(), nullable=False),
        sa.Column("distance_m", sa.Float(), nullable=False),
        sa.Column("elevation_gain_m", sa.Float(), nullable=False),
        sa.Column("elevation_loss_m", sa.Float(), nullable=False),
        sa.Column("max_speed_mps", sa.Float(), nullable=False),
        sa.Column("calories", sa.Integer(), nullable=False),
        sa.Column("comment", sa.Text(), nullable=True),
        sa.Column("route", sa.JSON(), nullable=False),
        sa.Column("splits", sa.JSON(), nullable=True),
        sa.CheckConstraint("distance_m >= 0", name="gps_distance_non_negative"),
        sa.CheckConstraint("moving_seconds >= 0", name="gps_moving_non_negative"),
    )
    op.create_index("ix_gps_activities_user_id_started_at", "gps_activities", ["user_id", "started_at"])


def downgrade() -> None:
    op.drop_index("ix_gps_activities_user_id_started_at", table_name="gps_activities")
    op.drop_table("gps_activities")
