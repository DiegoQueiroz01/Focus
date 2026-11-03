from datetime import datetime, timedelta, timezone
from typing import Annotated

from fastapi import APIRouter, Query
from sqlalchemy import func, select

from app.api.deps import CurrentUser, DbSession
from app.models import Exercise, Workout
from app.schemas.dashboard import DashboardSummary

router = APIRouter(prefix="/dashboard", tags=["dashboard"])


@router.get("/summary", response_model=DashboardSummary)
def get_summary(
    user: CurrentUser,
    db: DbSession,
    days: Annotated[int | None, Query(ge=1, le=365)] = None,
) -> DashboardSummary:
    filters = [Workout.user_id == user.id]
    if days is not None:
        filters.append(Workout.performed_at >= datetime.now(timezone.utc) - timedelta(days=days))

    total_workouts, total_minutes = db.execute(
        select(func.count(Workout.id), func.coalesce(func.sum(Workout.duration_minutes), 0)).where(
            *filters
        )
    ).one()

    total_sets = db.scalar(
        select(func.coalesce(func.sum(Exercise.sets), 0)).join(Exercise.workout).where(*filters)
    )

    return DashboardSummary(
        total_workouts=total_workouts,
        total_sets=total_sets,
        total_minutes=total_minutes,
        period_days=days,
    )
