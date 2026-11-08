from datetime import datetime
from typing import TYPE_CHECKING

from sqlalchemy import JSON, CheckConstraint, DateTime, Float, ForeignKey, Index, Integer, String, Text
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base

if TYPE_CHECKING:
    from app.models.user import User


class GpsActivity(Base):
    """Atividade ao ar livre gravada pelo GPS do celular (corrida, pedal, caminhada...)."""

    __tablename__ = "gps_activities"
    __table_args__ = (
        CheckConstraint("distance_m >= 0", name="gps_distance_non_negative"),
        CheckConstraint("moving_seconds >= 0", name="gps_moving_non_negative"),
        Index("ix_gps_activities_user_id_started_at", "user_id", "started_at"),
    )

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"))
    activity_type: Mapped[str] = mapped_column(String(30))
    started_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    finished_at: Mapped[datetime] = mapped_column(DateTime(timezone=True))
    # Tempo total (com pausas) e tempo em movimento.
    elapsed_seconds: Mapped[int] = mapped_column(Integer)
    moving_seconds: Mapped[int] = mapped_column(Integer)
    distance_m: Mapped[float] = mapped_column(Float)
    elevation_gain_m: Mapped[float] = mapped_column(Float, default=0)
    elevation_loss_m: Mapped[float] = mapped_column(Float, default=0)
    max_speed_mps: Mapped[float] = mapped_column(Float, default=0)
    calories: Mapped[int] = mapped_column(Integer, default=0)
    comment: Mapped[str | None] = mapped_column(Text)
    # Pontos [lat, lon, altitude|null, segundos desde o início].
    route: Mapped[list[list[float | None]]] = mapped_column(JSON)
    # Parciais: segundos gastos em cada km completo.
    splits: Mapped[list[int] | None] = mapped_column(JSON)

    user: Mapped["User"] = relationship(back_populates="gps_activities")
