from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import CheckConstraint, ForeignKey, Integer, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base

if TYPE_CHECKING:
    from app.models.workout import Workout


class Exercise(Base):
    __tablename__ = "exercises"
    __table_args__ = (
        CheckConstraint("sets >= 0", name="sets_non_negative"),
        CheckConstraint("reps >= 0", name="reps_non_negative"),
        CheckConstraint("weight_kg >= 0", name="weight_non_negative"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    workout_id: Mapped[int] = mapped_column(
        ForeignKey("workouts.id", ondelete="CASCADE"), index=True
    )
    position: Mapped[int] = mapped_column(Integer)
    name: Mapped[str] = mapped_column(String(120))
    muscle_group: Mapped[str] = mapped_column(String(30), default="other", server_default="other")
    sets: Mapped[int] = mapped_column(Integer)
    reps: Mapped[int] = mapped_column(Integer, default=0)
    weight_kg: Mapped[Decimal] = mapped_column(Numeric(6, 2), default=Decimal("0"))

    workout: Mapped["Workout"] = relationship(back_populates="exercises")
