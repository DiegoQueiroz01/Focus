from datetime import datetime
from decimal import Decimal
from typing import TYPE_CHECKING

from sqlalchemy import CheckConstraint, DateTime, ForeignKey, Index, Integer, Numeric, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base

if TYPE_CHECKING:
    from app.models.user import User
    from app.models.workout import Workout


class WorkoutSession(Base):
    """Uma execução de treino: começa ao tocar em "Iniciar" e termina em "Finalizar"."""

    __tablename__ = "workout_sessions"
    __table_args__ = (
        CheckConstraint("duration_seconds >= 0", name="duration_non_negative"),
        CheckConstraint("total_volume_kg >= 0", name="volume_non_negative"),
        CheckConstraint("total_sets >= 0", name="sets_non_negative"),
        Index("ix_workout_sessions_user_id_started_at", "user_id", "started_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    # Se o plano for excluído, o histórico continua (com o nome copiado abaixo).
    workout_id: Mapped[int | None] = mapped_column(
        ForeignKey("workouts.id", ondelete="SET NULL"), index=True
    )
    workout_name: Mapped[str] = mapped_column(String(120))
    workout_type: Mapped[str] = mapped_column(String(30))
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    finished_at: Mapped[datetime | None] = mapped_column(DateTime(timezone=True))
    duration_seconds: Mapped[int] = mapped_column(Integer, default=0)
    total_volume_kg: Mapped[Decimal] = mapped_column(Numeric(12, 2), default=Decimal("0"))
    total_sets: Mapped[int] = mapped_column(Integer, default=0)
    last_muscle_group: Mapped[str | None] = mapped_column(String(30))

    user: Mapped["User"] = relationship(back_populates="sessions")
    workout: Mapped["Workout | None"] = relationship()

    @property
    def is_active(self) -> bool:
        return self.finished_at is None
