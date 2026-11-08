from typing import Annotated

from fastapi import APIRouter, HTTPException, Query, Response, status
from sqlalchemy import func, select
from sqlalchemy.orm import selectinload

from app.api.deps import CurrentUser, DbSession
from app.core.config import get_settings
from app.core.time import utcnow
from app.models import Exercise, User, Workout, WorkoutSession
from app.schemas.session import SessionRead
from app.schemas.workout import ExerciseWrite, WorkoutPage, WorkoutRead, WorkoutWrite

router = APIRouter(prefix="/workouts", tags=["workouts"])


def _get_owned_workout(db: DbSession, user: User, workout_id: int) -> Workout:
    workout = db.scalar(
        select(Workout)
        .where(Workout.id == workout_id, Workout.user_id == user.id)
        .options(selectinload(Workout.exercises))
    )
    if workout is None:
        # 404 também para treinos de outros usuários, para não revelar que existem.
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Treino não encontrado")
    return workout


def _build_exercises(exercises: list[ExerciseWrite]) -> list[Exercise]:
    return [
        Exercise(
            position=position,
            name=exercise.name,
            muscle_group=exercise.muscle_group.value,
            sets=exercise.sets,
            reps=exercise.reps,
            weight_kg=exercise.weight_kg,
        )
        for position, exercise in enumerate(exercises)
    ]


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
        .order_by(Workout.created_at.desc(), Workout.id.desc())
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


@router.get("/{workout_id}", response_model=WorkoutRead)
def get_workout(workout_id: int, user: CurrentUser, db: DbSession) -> Workout:
    return _get_owned_workout(db, user, workout_id)


@router.post("", response_model=WorkoutRead, status_code=status.HTTP_201_CREATED)
def create_workout(payload: WorkoutWrite, user: CurrentUser, db: DbSession) -> Workout:
    workout = Workout(
        user_id=user.id,
        name=payload.name,
        type=payload.type.value,
        exercises=_build_exercises(payload.exercises),
    )
    db.add(workout)
    db.commit()
    db.refresh(workout, attribute_names=["exercises", "created_at"])
    return workout


@router.put("/{workout_id}", response_model=WorkoutRead)
def update_workout(
    workout_id: int, payload: WorkoutWrite, user: CurrentUser, db: DbSession
) -> Workout:
    workout = _get_owned_workout(db, user, workout_id)
    workout.name = payload.name
    workout.type = payload.type.value
    # A lista enviada substitui a anterior por completo.
    workout.exercises.clear()
    db.flush()
    workout.exercises.extend(_build_exercises(payload.exercises))
    db.commit()
    db.refresh(workout, attribute_names=["exercises"])
    return workout


@router.delete("/{workout_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_workout(workout_id: int, user: CurrentUser, db: DbSession) -> Response:
    workout = _get_owned_workout(db, user, workout_id)
    db.delete(workout)
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)


@router.post(
    "/{workout_id}/sessions", response_model=SessionRead, status_code=status.HTTP_201_CREATED
)
def start_session(workout_id: int, user: CurrentUser, db: DbSession) -> WorkoutSession:
    workout = _get_owned_workout(db, user, workout_id)

    active = db.scalar(
        select(WorkoutSession.id).where(
            WorkoutSession.user_id == user.id, WorkoutSession.finished_at.is_(None)
        )
    )
    if active is not None:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Você já tem um treino em andamento. Finalize-o antes de iniciar outro.",
        )

    session = WorkoutSession(
        user_id=user.id,
        workout_id=workout.id,
        workout_name=workout.name,
        workout_type=workout.type,
        started_at=utcnow(),
    )
    db.add(session)
    db.commit()
    return session
