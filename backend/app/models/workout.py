from typing import TYPE_CHECKING

from sqlalchemy import ForeignKey, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin

if TYPE_CHECKING:
    from app.models.exercise import Exercise
    from app.models.user import User


class Workout(TimestampMixin, Base):
    """Plano de treino (ex.: "Treino A — Peito"). Cada execução vira uma WorkoutSession."""

    __tablename__ = "workouts"

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    name: Mapped[str] = mapped_column(String(120))
    type: Mapped[str] = mapped_column(String(30))

    user: Mapped["User"] = relationship(back_populates="workouts")
    exercises: Mapped[list["Exercise"]] = relationship(
        back_populates="workout",
        cascade="all, delete-orphan",
        passive_deletes=True,
        order_by="Exercise.position",
    )

    @property
    def total_sets(self) -> int:
        return sum(exercise.sets for exercise in self.exercises)
