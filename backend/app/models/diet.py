import datetime as dt
from typing import TYPE_CHECKING

from sqlalchemy import CheckConstraint, Date, Float, ForeignKey, Index, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin

if TYPE_CHECKING:
    from app.models.user import User


class WeightEntry(TimestampMixin, Base):
    """Peso do usuário em um dia (no máximo um registro por dia). O mais recente é o peso atual."""

    __tablename__ = "weight_entries"
    __table_args__ = (
        UniqueConstraint("user_id", "date", name="uq_weight_entries_user_date"),
        CheckConstraint("weight_kg > 0", name="weight_positive"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    date: Mapped[dt.date] = mapped_column(Date)
    weight_kg: Mapped[float] = mapped_column(Float)

    user: Mapped["User"] = relationship(back_populates="weight_entries")


class CustomFood(TimestampMixin, Base):
    """Alimento cadastrado pelo próprio usuário (ex.: a partir do rótulo). Valores por 100 g."""

    __tablename__ = "custom_foods"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(120))
    kcal: Mapped[float] = mapped_column(Float)
    protein: Mapped[float] = mapped_column(Float)
    carbs: Mapped[float] = mapped_column(Float)
    fat: Mapped[float] = mapped_column(Float)
    fiber: Mapped[float] = mapped_column(Float, default=0)
    # Porção do rótulo, oferecida como atalho ao registrar.
    serving_label: Mapped[str | None] = mapped_column(String(60))
    serving_grams: Mapped[float | None] = mapped_column(Float)

    user: Mapped["User"] = relationship(back_populates="custom_foods")


class FoodEntry(TimestampMixin, Base):
    """Alimento comido em uma refeição. Guarda uma cópia dos valores por 100 g para que o
    histórico não mude se a base de alimentos for atualizada ou o alimento apagado."""

    __tablename__ = "food_entries"
    __table_args__ = (
        CheckConstraint("grams > 0", name="food_grams_positive"),
        Index("ix_food_entries_user_id_date", "user_id", "date"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    date: Mapped[dt.date] = mapped_column(Date)
    meal: Mapped[str] = mapped_column(String(30))
    food_id: Mapped[str] = mapped_column(String(40))
    name: Mapped[str] = mapped_column(String(120))
    grams: Mapped[float] = mapped_column(Float)
    portion_label: Mapped[str | None] = mapped_column(String(60))
    kcal_100g: Mapped[float] = mapped_column(Float)
    protein_100g: Mapped[float] = mapped_column(Float)
    carbs_100g: Mapped[float] = mapped_column(Float)
    fat_100g: Mapped[float] = mapped_column(Float)
    fiber_100g: Mapped[float] = mapped_column(Float, default=0)

    user: Mapped["User"] = relationship(back_populates="food_entries")
