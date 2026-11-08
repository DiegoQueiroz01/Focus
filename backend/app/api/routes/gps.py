from typing import Annotated

from fastapi import APIRouter, HTTPException, Query, Response, status
from sqlalchemy import select

from app.api.deps import CurrentUser, DbSession
from app.core.time import as_utc
from app.gps import estimate_calories
from app.models import GpsActivity, User
from app.schemas.gps import GpsActivityCreate, GpsActivityDetail, GpsActivitySummary, GpsCommentUpdate

router = APIRouter(prefix="/gps-activities", tags=["gps"])


def _get_owned(db: DbSession, user: User, activity_id: int) -> GpsActivity:
    activity = db.scalar(
        select(GpsActivity).where(GpsActivity.id == activity_id, GpsActivity.user_id == user.id)
    )
    if activity is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Atividade não encontrada")
    return activity


@router.get("", response_model=list[GpsActivitySummary])
def list_activities(
    user: CurrentUser,
    db: DbSession,
    limit: Annotated[int, Query(ge=1, le=100)] = 30,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> list[GpsActivity]:
    query = (
        select(GpsActivity)
        .where(GpsActivity.user_id == user.id)
        .order_by(GpsActivity.started_at.desc(), GpsActivity.id.desc())
        .offset(offset)
        .limit(limit)
    )
    return list(db.scalars(query).all())


@router.post("", response_model=GpsActivityDetail, status_code=status.HTTP_201_CREATED)
def create_activity(payload: GpsActivityCreate, user: CurrentUser, db: DbSession) -> GpsActivity:
    activity = GpsActivity(
        user_id=user.id,
        **payload.model_dump(exclude={"activity_type", "started_at", "finished_at"}),
        activity_type=payload.activity_type.value,
        started_at=as_utc(payload.started_at),
        finished_at=as_utc(payload.finished_at),
        calories=estimate_calories(payload.activity_type, payload.moving_seconds),
    )
    db.add(activity)
    db.commit()
    return activity


@router.get("/{activity_id}", response_model=GpsActivityDetail)
def get_activity(activity_id: int, user: CurrentUser, db: DbSession) -> GpsActivity:
    return _get_owned(db, user, activity_id)


@router.put("/{activity_id}/comment", response_model=GpsActivityDetail)
def update_comment(
    activity_id: int, payload: GpsCommentUpdate, user: CurrentUser, db: DbSession
) -> GpsActivity:
    activity = _get_owned(db, user, activity_id)
    activity.comment = payload.comment
    db.commit()
    return activity


@router.delete("/{activity_id}", status_code=status.HTTP_204_NO_CONTENT)
def delete_activity(activity_id: int, user: CurrentUser, db: DbSession) -> Response:
    db.delete(_get_owned(db, user, activity_id))
    db.commit()
    return Response(status_code=status.HTTP_204_NO_CONTENT)
