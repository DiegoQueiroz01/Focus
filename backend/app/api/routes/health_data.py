from datetime import date, timedelta
from typing import Annotated

from fastapi import APIRouter, HTTPException, Query, status
from sqlalchemy import select

from app.api.deps import CurrentUser, DbSession
from app.core.time import as_utc, utcnow
from app.models import HealthDay
from app.schemas.health import HealthDayOut, HealthSyncIn, HealthSyncOut

router = APIRouter(prefix="/health-data", tags=["health"])

# Maior intervalo que pode ser consultado de uma vez.
MAX_RANGE_DAYS = 400


@router.put("/days", response_model=HealthSyncOut)
def sync_days(payload: HealthSyncIn, user: CurrentUser, db: DbSession) -> HealthSyncOut:
    """Grava os resumos diários vindos do relógio. Reenviar o mesmo dia atualiza o registro."""
    dates = [d.date for d in payload.days]
    existing = {
        row.date: row
        for row in db.scalars(
            select(HealthDay).where(HealthDay.user_id == user.id, HealthDay.date.in_(dates))
        )
    }
    now = utcnow()
    created = updated = 0
    for day in payload.days:
        values = day.model_dump(exclude={"date"}, exclude_none=True)
        for field in ("sleep_start", "sleep_end"):
            if field in values:
                values[field] = as_utc(values[field])

        row = existing.get(day.date)
        if row is None:
            db.add(HealthDay(user_id=user.id, date=day.date, synced_at=now, **values))
            created += 1
        else:
            for field, value in values.items():
                setattr(row, field, value)
            row.synced_at = now
            updated += 1
    db.commit()
    return HealthSyncOut(created=created, updated=updated)


@router.get("/days", response_model=list[HealthDayOut])
def list_days(
    user: CurrentUser,
    db: DbSession,
    start: Annotated[date | None, Query(description="Primeiro dia (inclusivo)")] = None,
    end: Annotated[date | None, Query(description="Último dia (inclusivo)")] = None,
) -> list[HealthDay]:
    """Dias com dados do relógio, do mais antigo para o mais recente. Padrão: últimos 30 dias."""
    end = end or utcnow().date()
    start = start or end - timedelta(days=29)
    if start > end:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "start depois de end")
    if (end - start).days >= MAX_RANGE_DAYS:
        raise HTTPException(status.HTTP_422_UNPROCESSABLE_ENTITY, "Intervalo muito longo")
    query = (
        select(HealthDay)
        .where(HealthDay.user_id == user.id, HealthDay.date >= start, HealthDay.date <= end)
        .order_by(HealthDay.date)
    )
    return list(db.scalars(query))
