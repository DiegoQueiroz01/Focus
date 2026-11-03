from datetime import datetime, timezone
from typing import Annotated

from fastapi import APIRouter, Query, status
from sqlalchemy import func, select
from sqlalchemy.orm import selectinload

from app.api.deps import CurrentUser, DbSession
from app.core.config import get_settings
from app.models import Exercise, Workout
from app.schemas.workout import WorkoutCreate, WorkoutPage, WorkoutRead

router = APIRouter(prefix="/workouts", tags=["workouts"])


@router.get("", response_model=WorkoutPage)
def list_workouts(
    user: CurrentUser,
    db: DbSession,
    offset: Annotated[int, Query(ge=0)] = 0,
    limit: Annotated[int, Query(ge=1)] = 20,
) -> WorkoutPage:
    limit = min(limit, get_settings().workouts_page_max)

    total = db.scalar(select(func.count(Workout.id)).where(Workout.user_id == user.id))
    workouts = db.scalars(
        select(Workout)
        .where(Workout.user_id == user.id)
        .options(selectinload(Workout.exercises))
        .order_by(Workout.performed_at.desc(), Workout.id.desc())
        .offset(offset)
        .limit(limit)
    ).all()

    return WorkoutPage(
        items=[WorkoutRead.model_validate(w) for w in workouts],
        total=total,
        offset=offset,
        limit=limit,
        has_more=offset + len(workouts) < total,
    )


@router.post("", response_model=WorkoutRead, status_code=status.HTTP_201_CREATED)
def create_workout(payload: WorkoutCreate, user: CurrentUser, db: DbSession) -> WorkoutRead:
    workout = Workout(
        user_id=user.id,
        name=payload.name,
        type=payload.type.value,
        performed_at=payload.performed_at or datetime.now(timezone.utc),
        duration_minutes=payload.duration_minutes,
        exercises=[
            Exercise(
                position=position,
                name=exercise.name,
                sets=exercise.sets,
                reps=exercise.reps,
                weight_kg=exercise.weight_kg,
            )
            for position, exercise in enumerate(payload.exercises)
        ],
    )
    db.add(workout)
    db.commit()
    db.refresh(workout, attribute_names=["exercises"])
    return WorkoutRead.model_validate(workout)
