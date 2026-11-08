from datetime import date

from pydantic import BaseModel


class DayTotals(BaseModel):
    date: date
    sessions: int
    duration_seconds: int
    volume_kg: float
    sets: int


class WeekSummary(BaseModel):
    start: date
    end: date
    total_sessions: int
    total_duration_seconds: int
    total_volume_kg: float
    total_sets: int
    days: list[DayTotals]
    # Séries por músculo somadas na semana.
    muscle_load: dict[str, float]


class Streak(BaseModel):
    current: int
    best: int
    trained_today: bool


class HeatmapDay(BaseModel):
    date: date
    count: int


class Heatmap(BaseModel):
    start: date
    end: date
    days: list[HeatmapDay]


class DashboardOverview(BaseModel):
    week: WeekSummary
    streak: Streak
    heatmap: Heatmap
