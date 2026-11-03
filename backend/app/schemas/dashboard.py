from pydantic import BaseModel


class DashboardSummary(BaseModel):
    total_workouts: int
    total_sets: int
    total_minutes: int
    period_days: int | None
