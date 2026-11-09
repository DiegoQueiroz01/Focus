import datetime as dt
from typing import TYPE_CHECKING

from sqlalchemy import Boolean, Date, Float, Integer, String
from sqlalchemy.orm import Mapped, mapped_column, relationship

from app.models.base import Base, TimestampMixin

if TYPE_CHECKING:
    from app.models.diet import CustomFood, FoodEntry, WeightEntry
    from app.models.gps_activity import GpsActivity
    from app.models.workout import Workout
    from app.models.workout_session import WorkoutSession


class User(TimestampMixin, Base):
    __tablename__ = "users"

    id: Mapped[int] = mapped_column(primary_key=True)
    name: Mapped[str] = mapped_column(String(80), default="", server_default="")
    # Sempre salvo em minúsculas. Nulo apenas em contas antigas criadas pelo CLI com username.
    email: Mapped[str | None] = mapped_column(String(254), unique=True, index=True)
    username: Mapped[str | None] = mapped_column(String(50), unique=True, index=True)
    password_hash: Mapped[str] = mapped_column(String(255))
    # Foto vinda de um login social (ex.: Google). Sem ela, usa-se o Gravatar do e-mail.
    avatar_url: Mapped[str | None] = mapped_column(String(500))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true")

    # Perfil corporal e objetivo (preenchidos no questionário da dieta). O peso fica em
    # weight_entries; o registro mais recente é o peso atual.
    sex: Mapped[str | None] = mapped_column(String(10))
    birth_date: Mapped[dt.date | None] = mapped_column(Date)
    height_cm: Mapped[float | None] = mapped_column(Float)
    activity_level: Mapped[str | None] = mapped_column(String(20))
    goal: Mapped[str | None] = mapped_column(String(10))
    goal_pace: Mapped[str | None] = mapped_column(String(10))
    target_weight_kg: Mapped[float | None] = mapped_column(Float)
    # Meta de calorias escolhida pelo usuário no lugar da calculada.
    calorie_override: Mapped[int | None] = mapped_column(Integer)

    workouts: Mapped[list["Workout"]] = relationship(
        back_populates="user", cascade="all, delete-orphan", passive_deletes=True
    )
    sessions: Mapped[list["WorkoutSession"]] = relationship(
        back_populates="user", cascade="all, delete-orphan", passive_deletes=True
    )
    gps_activities: Mapped[list["GpsActivity"]] = relationship(
        back_populates="user", cascade="all, delete-orphan", passive_deletes=True
    )
    weight_entries: Mapped[list["WeightEntry"]] = relationship(
        back_populates="user", cascade="all, delete-orphan", passive_deletes=True
    )
    custom_foods: Mapped[list["CustomFood"]] = relationship(
        back_populates="user", cascade="all, delete-orphan", passive_deletes=True
    )
    food_entries: Mapped[list["FoodEntry"]] = relationship(
        back_populates="user", cascade="all, delete-orphan", passive_deletes=True
    )
