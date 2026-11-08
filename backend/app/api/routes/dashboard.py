from collections import Counter
from datetime import date, timedelta
from typing import Annotated

from fastapi import APIRouter, Query
from sqlalchemy import select

from app.api.deps import CurrentUser, DbSession
from app.core.time import local_date, utcnow
from app.models import WorkoutSession
from app.schemas.dashboard import (
    DashboardOverview,
    DayTotals,
    Heatmap,
    HeatmapDay,
    Streak,
    WeekSummary,
)

router = APIRouter(prefix="/dashboard", tags=["dashboard"])


def compute_streak(days: set[date], today: date) -> Streak:
    """Dias seguidos com pelo menos uma sessão iniciada.

    Se o usuário ainda não treinou hoje, mas treinou ontem, a sequência continua
    valendo; ela só zera depois de um dia inteiro sem treino.
    """
    trained_today = today in days
    cursor = today if trained_today else today - timedelta(days=1)
    current = 0
    while cursor in days:
        current += 1
        cursor -= timedelta(days=1)

    best = run = 0
    previous: date | None = None
    for day in sorted(days):
        run = run + 1 if previous is not None and day - previous == timedelta(days=1) else 1
        best = max(best, run)
        previous = day

    return Streak(current=current, best=best, trained_today=trained_today)


@router.get("/overview", response_model=DashboardOverview)
def get_overview(
    user: CurrentUser,
    db: DbSession,
    tz_offset_minutes: Annotated[
        int,
        Query(ge=-14 * 60, le=14 * 60, description="Fuso do aparelho em minutos (Brasília: -180)"),
    ] = 0,
    heatmap_days: Annotated[int, Query(ge=7, le=371)] = 364,
) -> DashboardOverview:
    offset = timedelta(minutes=tz_offset_minutes)
    today = local_date(utcnow(), offset)
    week_start = today - timedelta(days=today.weekday())  # segunda-feira
    heatmap_start = today - timedelta(days=heatmap_days - 1)

    rows = db.execute(
        select(
            WorkoutSession.started_at,
            WorkoutSession.duration_seconds,
            WorkoutSession.total_volume_kg,
            WorkoutSession.total_sets,
        ).where(WorkoutSession.user_id == user.id)
    ).all()

    week = {
        week_start + timedelta(days=i): DayTotals(
            date=week_start + timedelta(days=i),
            sessions=0,
            duration_seconds=0,
            volume_kg=0,
            sets=0,
        )
        for i in range(7)
    }
    all_days: set[date] = set()
    heatmap_counts: Counter[date] = Counter()

    for started_at, duration, volume, sets in rows:
        day = local_date(started_at, offset)
        all_days.add(day)
        if heatmap_start <= day <= today:
            heatmap_counts[day] += 1
        totals = week.get(day)
        if totals is not None:
            totals.sessions += 1
            totals.duration_seconds += duration
            totals.volume_kg = round(totals.volume_kg + float(volume), 2)
            totals.sets += sets

    days = list(week.values())
    return DashboardOverview(
        week=WeekSummary(
            start=week_start,
            end=week_start + timedelta(days=6),
            total_sessions=sum(d.sessions for d in days),
            total_duration_seconds=sum(d.duration_seconds for d in days),
            total_volume_kg=round(sum(d.volume_kg for d in days), 2),
            total_sets=sum(d.sets for d in days),
            days=days,
        ),
        streak=compute_streak(all_days, today),
        heatmap=Heatmap(
            start=heatmap_start,
            end=today,
            days=[HeatmapDay(date=d, count=c) for d, c in sorted(heatmap_counts.items())],
        ),
    )
