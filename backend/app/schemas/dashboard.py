from datetime import date

from pydantic import BaseModel


class DayTotals(BaseModel):
    date: date
    # Treinos de academia; as atividades por GPS ficam em `gps_activities`.
    sessions: int
    gps_activities: int = 0
    # Tempo dos treinos somado ao tempo em movimento das atividades por GPS.
    duration_seconds: int
    volume_kg: float
    sets: int
    distance_m: float = 0


class WeekSummary(BaseModel):
    start: date
    end: date
    total_sessions: int
    total_gps_activities: int = 0
    total_duration_seconds: int
    total_volume_kg: float
    total_sets: int
    total_distance_m: float = 0
    days: list[DayTotals]
    # Séries por músculo somadas na semana (treinos e atividades por GPS).
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
