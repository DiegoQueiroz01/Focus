from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, computed_field, field_validator, model_validator

from app.gps import GpsActivityType, route_preview

# ~14h de gravação com um ponto a cada 2,5 s.
MAX_ROUTE_POINTS = 20_000


def _clean_comment(value: str | None) -> str | None:
    return (value or "").strip() or None


class GpsActivityCreate(BaseModel):
    activity_type: GpsActivityType
    started_at: datetime
    finished_at: datetime
    elapsed_seconds: int = Field(ge=0, le=48 * 3600)
    moving_seconds: int = Field(ge=0, le=48 * 3600)
    distance_m: float = Field(ge=0, le=1_000_000)
    elevation_gain_m: float = Field(default=0, ge=0, le=50_000)
    elevation_loss_m: float = Field(default=0, ge=0, le=50_000)
    max_speed_mps: float = Field(default=0, ge=0, le=100)
    comment: str | None = Field(default=None, max_length=2000)
    route: list[list[float | None]] = Field(default_factory=list, max_length=MAX_ROUTE_POINTS)
    splits: list[int] = Field(default_factory=list, max_length=1000)

    @field_validator("route")
    @classmethod
    def _valid_points(cls, route: list[list[float | None]]) -> list[list[float | None]]:
        for point in route:
            if len(point) != 4 or point[0] is None or point[1] is None:
                raise ValueError("cada ponto deve ser [lat, lon, altitude, segundos]")
            if not (-90 <= point[0] <= 90 and -180 <= point[1] <= 180):
                raise ValueError("coordenada fora do intervalo")
        return route

    @field_validator("comment")
    @classmethod
    def _strip_comment(cls, value: str | None) -> str | None:
        return _clean_comment(value)

    @model_validator(mode="after")
    def _consistent_times(self) -> "GpsActivityCreate":
        if self.finished_at < self.started_at:
            raise ValueError("finished_at antes de started_at")
        if self.moving_seconds > self.elapsed_seconds:
            raise ValueError("tempo em movimento maior que o tempo total")
        return self


class GpsCommentUpdate(BaseModel):
    comment: str | None = Field(default=None, max_length=2000)

    @field_validator("comment")
    @classmethod
    def _strip(cls, value: str | None) -> str | None:
        return _clean_comment(value)


class GpsActivitySummary(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    activity_type: GpsActivityType
    started_at: datetime
    finished_at: datetime
    elapsed_seconds: int
    moving_seconds: int
    distance_m: float
    elevation_gain_m: float
    elevation_loss_m: float
    max_speed_mps: float
    calories: int
    comment: str | None
    route: list[list[float | None]] = Field(exclude=True)

    @computed_field
    @property
    def route_preview(self) -> list[list[float]]:
        return route_preview(self.route)


class GpsActivityDetail(GpsActivitySummary):
    route: list[list[float | None]]
    splits: list[int]

    @field_validator("splits", mode="before")
    @classmethod
    def _empty(cls, value: list[int] | None) -> list[int]:
        return value or []
