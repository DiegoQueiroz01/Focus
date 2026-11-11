import datetime as dt
from typing import TYPE_CHECKING

from sqlalchemy import JSON, Date, DateTime, Float, ForeignKey, Integer, String, UniqueConstraint
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base

if TYPE_CHECKING:
    from app.models.user import User


class HealthDay(Base):
    """Resumo de um dia vindo do relógio (via Health Connect no celular). Um registro por dia.

    Todos os campos de medida são opcionais: cada relógio entrega um conjunto diferente de dados.
    O sono pertence ao dia em que a pessoa acordou.
    """

    __tablename__ = "health_days"
    __table_args__ = (UniqueConstraint("user_id", "date", name="uq_health_days_user_date"),)

    id: Mapped[int] = mapped_column(primary_key=True)
    user_id: Mapped[int] = mapped_column(ForeignKey("users.id", ondelete="CASCADE"), index=True)
    date: Mapped[dt.date] = mapped_column(Date)

    steps: Mapped[int | None] = mapped_column(Integer)
    distance_m: Mapped[float | None] = mapped_column(Float)
    active_calories: Mapped[int | None] = mapped_column(Integer)

    resting_hr: Mapped[int | None] = mapped_column(Integer)
    avg_hr: Mapped[int | None] = mapped_column(Integer)
    min_hr: Mapped[int | None] = mapped_column(Integer)
    max_hr: Mapped[int | None] = mapped_column(Integer)
    # Média por intervalo do dia: [[minuto do dia, bpm], ...].
    heart_rate_series: Mapped[list[list[int]] | None] = mapped_column(JSON)

    sleep_minutes: Mapped[int | None] = mapped_column(Integer)
    sleep_deep_minutes: Mapped[int | None] = mapped_column(Integer)
    sleep_light_minutes: Mapped[int | None] = mapped_column(Integer)
    sleep_rem_minutes: Mapped[int | None] = mapped_column(Integer)
    sleep_awake_minutes: Mapped[int | None] = mapped_column(Integer)
    sleep_start: Mapped[dt.datetime | None] = mapped_column(DateTime(timezone=True))
    sleep_end: Mapped[dt.datetime | None] = mapped_column(DateTime(timezone=True))

    spo2_avg: Mapped[float | None] = mapped_column(Float)
    spo2_min: Mapped[float | None] = mapped_column(Float)

    synced_at: Mapped[dt.datetime] = mapped_column(DateTime(timezone=True))

    user: Mapped["User"] = relationship(back_populates="health_days")
