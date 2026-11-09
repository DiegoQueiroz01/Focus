"""dieta: perfil corporal, peso, alimentos personalizados e diário alimentar

Revision ID: a7d3e5f1c2b8
Revises: f4a2c8e1b9d6
Create Date: 2026-11-09 13:00:00
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op


revision: str = "a7d3e5f1c2b8"
down_revision: str | None = "f4a2c8e1b9d6"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    with op.batch_alter_table("users") as batch:
        batch.add_column(sa.Column("sex", sa.String(length=10), nullable=True))
        batch.add_column(sa.Column("birth_date", sa.Date(), nullable=True))
        batch.add_column(sa.Column("height_cm", sa.Float(), nullable=True))
        batch.add_column(sa.Column("activity_level", sa.String(length=20), nullable=True))
        batch.add_column(sa.Column("goal", sa.String(length=10), nullable=True))
        batch.add_column(sa.Column("goal_pace", sa.String(length=10), nullable=True))
        batch.add_column(sa.Column("target_weight_kg", sa.Float(), nullable=True))
        batch.add_column(sa.Column("calorie_override", sa.Integer(), nullable=True))

    op.create_table(
        "weight_entries",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("weight_kg", sa.Float(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.UniqueConstraint("user_id", "date", name="uq_weight_entries_user_date"),
        sa.CheckConstraint("weight_kg > 0", name="weight_positive"),
    )
    op.create_index("ix_weight_entries_user_id", "weight_entries", ["user_id"])

    op.create_table(
        "custom_foods",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("kcal", sa.Float(), nullable=False),
        sa.Column("protein", sa.Float(), nullable=False),
        sa.Column("carbs", sa.Float(), nullable=False),
        sa.Column("fat", sa.Float(), nullable=False),
        sa.Column("fiber", sa.Float(), nullable=False),
        sa.Column("serving_label", sa.String(length=60), nullable=True),
        sa.Column("serving_grams", sa.Float(), nullable=True),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
    )
    op.create_index("ix_custom_foods_user_id", "custom_foods", ["user_id"])

    op.create_table(
        "food_entries",
        sa.Column("id", sa.Integer(), primary_key=True),
        sa.Column("user_id", sa.Integer(), sa.ForeignKey("users.id", ondelete="CASCADE"), nullable=False),
        sa.Column("date", sa.Date(), nullable=False),
        sa.Column("meal", sa.String(length=30), nullable=False),
        sa.Column("food_id", sa.String(length=40), nullable=False),
        sa.Column("name", sa.String(length=120), nullable=False),
        sa.Column("grams", sa.Float(), nullable=False),
        sa.Column("portion_label", sa.String(length=60), nullable=True),
        sa.Column("kcal_100g", sa.Float(), nullable=False),
        sa.Column("protein_100g", sa.Float(), nullable=False),
        sa.Column("carbs_100g", sa.Float(), nullable=False),
        sa.Column("fat_100g", sa.Float(), nullable=False),
        sa.Column("fiber_100g", sa.Float(), nullable=False),
        sa.Column("created_at", sa.DateTime(timezone=True), server_default=sa.func.now(), nullable=False),
        sa.CheckConstraint("grams > 0", name="food_grams_positive"),
    )
    op.create_index("ix_food_entries_user_id_date", "food_entries", ["user_id", "date"])


def downgrade() -> None:
    op.drop_index("ix_food_entries_user_id_date", table_name="food_entries")
    op.drop_table("food_entries")
    op.drop_index("ix_custom_foods_user_id", table_name="custom_foods")
    op.drop_table("custom_foods")
    op.drop_index("ix_weight_entries_user_id", table_name="weight_entries")
    op.drop_table("weight_entries")
    with op.batch_alter_table("users") as batch:
        for column in (
            "calorie_override",
            "target_weight_kg",
            "goal_pace",
            "goal",
            "activity_level",
            "height_cm",
            "birth_date",
            "sex",
        ):
            batch.drop_column(column)
