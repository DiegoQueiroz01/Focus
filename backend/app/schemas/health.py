import datetime as dt

from pydantic import BaseModel, ConfigDict, Field, field_validator, model_validator

# Um dia tem 1440 minutos; o app envia no máximo um ponto a cada 5 min.
MAX_HR_POINTS = 1440
# Quantos dias podem ser enviados de uma vez.
MAX_DAYS_PER_SYNC = 120


class HealthDayIn(BaseModel):
    """Resumo de um dia enviado pelo app. Campos nulos não apagam o que já está salvo."""

    date: dt.date
    steps: int | None = Field(default=None, ge=0, le=200_000)
    distance_m: float | None = Field(default=None, ge=0, le=500_000)
    active_calories: int | None = Field(default=None, ge=0, le=20_000)

    resting_hr: int | None = Field(default=None, ge=20, le=250)
    avg_hr: int | None = Field(default=None, ge=20, le=250)
    min_hr: int | None = Field(default=None, ge=20, le=250)
    max_hr: int | None = Field(default=None, ge=20, le=250)
    heart_rate_series: list[list[int]] | None = Field(default=None, max_length=MAX_HR_POINTS)

    sleep_minutes: int | None = Field(default=None, ge=0, le=24 * 60)
    sleep_deep_minutes: int | None = Field(default=None, ge=0, le=24 * 60)
    sleep_light_minutes: int | None = Field(default=None, ge=0, le=24 * 60)
    sleep_rem_minutes: int | None = Field(default=None, ge=0, le=24 * 60)
    sleep_awake_minutes: int | None = Field(default=None, ge=0, le=24 * 60)
    sleep_start: dt.datetime | None = None
    sleep_end: dt.datetime | None = None

    spo2_avg: float | None = Field(default=None, ge=50, le=100)
    spo2_min: float | None = Field(default=None, ge=50, le=100)

    @field_validator("heart_rate_series")
    @classmethod
    def _valid_series(cls, series: list[list[int]] | None) -> list[list[int]] | None:
        for point in series or []:
            if len(point) != 2 or not (0 <= point[0] < 1440) or not (20 <= point[1] <= 250):
                raise ValueError("cada ponto deve ser [minuto do dia (0-1439), bpm (20-250)]")
        return series

    @model_validator(mode="after")
    def _consistent(self) -> "HealthDayIn":
        if self.min_hr is not None and self.max_hr is not None and self.min_hr > self.max_hr:
            raise ValueError("min_hr maior que max_hr")
        if self.sleep_start and self.sleep_end and self.sleep_end < self.sleep_start:
            raise ValueError("sleep_end antes de sleep_start")
        return self


class HealthSyncIn(BaseModel):
    days: list[HealthDayIn] = Field(min_length=1, max_length=MAX_DAYS_PER_SYNC)

    @field_validator("days")
    @classmethod
    def _unique_dates(cls, days: list[HealthDayIn]) -> list[HealthDayIn]:
        if len({d.date for d in days}) != len(days):
            raise ValueError("datas repetidas")
        return days


class HealthSyncOut(BaseModel):
    created: int
    updated: int


class HealthDayOut(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    date: dt.date
    steps: int | None
    distance_m: float | None
    active_calories: int | None
    resting_hr: int | None
    avg_hr: int | None
    min_hr: int | None
    max_hr: int | None
    heart_rate_series: list[list[int]]
    sleep_minutes: int | None
    sleep_deep_minutes: int | None
    sleep_light_minutes: int | None
    sleep_rem_minutes: int | None
    sleep_awake_minutes: int | None
    sleep_start: dt.datetime | None
    sleep_end: dt.datetime | None
    spo2_avg: float | None
    spo2_min: float | None
    synced_at: dt.datetime

    @field_validator("heart_rate_series", mode="before")
    @classmethod
    def _empty(cls, value: list[list[int]] | None) -> list[list[int]]:
        return value or []
