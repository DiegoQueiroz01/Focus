from datetime import datetime
from typing import Annotated

from fastapi import APIRouter, HTTPException, Query, Response, status
from sqlalchemy import select

from app.api.deps import CurrentUser, DbSession
from app.core.time import as_utc, utcnow
from app.models import Exercise, User, WorkoutSession
from app.muscle_load import compute_muscle_load
from app.schemas.session import SessionFinish, SessionRead

router = APIRouter(prefix="/sessions", tags=["sessions"])

# Teto para sessões esquecidas abertas: nenhuma sessão conta mais de 24h.
MAX_SESSION_SECONDS = 24 * 60 * 60


def _get_owned_session(db: DbSession, user: User, session_id: int) -> WorkoutSession:
    session = db.scalar(
        select(WorkoutSession).where(
            WorkoutSession.id == session_id, WorkoutSession.user_id == user.id
        )
    )
    if session is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Sessão não encontrada")
    return session


@router.get("", response_model=list[SessionRead])
def list_sessions(
    user: CurrentUser,
    db: DbSession,
    start: Annotated[datetime | None, Query(description="Início (inclusivo), ISO 8601")] = None,
    end: Annotated[datetime | None, Query(description="Fim (exclusivo), ISO 8601")] = None,
    limit: Annotated[int, Query(ge=1, le=200)] = 50,
) -> list[WorkoutSession]:
    query = select(WorkoutSession).where(WorkoutSession.user_id == user.id)
    if start is not None:
        query = query.where(WorkoutSession.started_at >= as_utc(start))
    if end is not None:
        query = query.where(WorkoutSession.started_at < as_utc(end))
    query = query.order_by(WorkoutSession.started_at.desc(), WorkoutSession.id.desc()).limit(limit)
    return list(db.scalars(query).all())


@router.get("/active", response_model=SessionRead | None)
def get_active_session(user: CurrentUser, db: DbSession) -> WorkoutSession | None:
    return db.scalar(
        select(WorkoutSession).where(
            WorkoutSession.user_id == user.id, WorkoutSession.finished_at.is_(None)
        )
    )


@router.post("/{session_id}/finish", response_model=SessionRead)
def finish_session(
    session_id: int, payload: SessionFinish, user: CurrentUser, db: DbSession
) -> WorkoutSession:
    session = _get_owned_session(db, user, session_id)
    if session.finished_at is not None:
        raise HTTPException(status_code=status.HTTP_409_CONFLICT, detail="Sessão já finalizada")

    now = utcnow()
    elapsed = int((now - as_utc(session.started_at)).total_seconds())
    session.finished_at = now
    session.duration_seconds = max(0, min(elapsed, MAX_SESSION_SECONDS))
    session.total_volume_kg = payload.total_volume_kg
    session.total_sets = payload.total_sets
    session.last_muscle_group = (
        payload.last_muscle_group.value if payload.last_muscle_group else None
    )
    if session.workout_id is not None and payload.completed_sets:
        exercises = db.scalars(select(Exercise).where(Exercise.workout_id == session.workout_id)).all()
        session.muscle_load = compute_muscle_load(
            exercises, {item.exercise_id: item.sets for item in payload.completed_sets}
        )
    db.commit()
    return session


@router.delete("/{session_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_session(session_id: int, user: CurrentUser, db: DbSession) -> Response:
    session = _get_owned_session(db, user, session_id)
    db.delete(session)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
