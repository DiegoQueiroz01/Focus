from typing import Annotated

from fastapi import APIRouter, HTTPException, Query, status

from app.api.deps import CurrentUser
from app.catalog import CatalogExercise, catalog_by_id, search_catalog
from app.core.config import get_settings
from app.schemas.catalog import CatalogExerciseDetail, CatalogExerciseSummary, CatalogPage
from app.schemas.workout import MuscleGroup, WorkoutType

router = APIRouter(prefix="/catalog", tags=["catalog"])


def _image_urls(exercise: CatalogExercise) -> list[str]:
    base = get_settings().catalog_image_base_url.rstrip("/")
    return [f"{base}/{path}" for path in exercise.images]


def _summary_fields(exercise: CatalogExercise) -> dict:
    urls = _image_urls(exercise)
    return {
        "id": exercise.id,
        "name": exercise.name,
        "name_en": exercise.name_en,
        "type": exercise.type,
        "muscle_group": exercise.muscle_group,
        "primary_muscles": list(exercise.primary_muscles),
        "secondary_muscles": list(exercise.secondary_muscles),
        "equipment": exercise.equipment,
        "level": exercise.level,
        "image_url": urls[0] if urls else None,
        "icon": exercise.icon,
    }


@router.get("/exercises", response_model=CatalogPage)
def list_catalog(
    _: CurrentUser,
    q: Annotated[str | None, Query(max_length=80, description="Busca por nome (pt ou en)")] = None,
    type: Annotated[WorkoutType | None, Query()] = None,
    muscle_group: Annotated[MuscleGroup | None, Query()] = None,
    offset: Annotated[int, Query(ge=0)] = 0,
    limit: Annotated[int, Query(ge=1, le=100)] = 30,
) -> CatalogPage:
    results = search_catalog(q, type.value if type else None, muscle_group)
    page = results[offset : offset + limit]
    return CatalogPage(
        items=[CatalogExerciseSummary(**_summary_fields(e)) for e in page],
        total=len(results),
        offset=offset,
        limit=limit,
        has_more=offset + len(page) < len(results),
    )


@router.get("/exercises/{exercise_id}", response_model=CatalogExerciseDetail)
def get_catalog_exercise(exercise_id: str, _: CurrentUser) -> CatalogExerciseDetail:
    exercise = catalog_by_id().get(exercise_id)
    if exercise is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Exercício não encontrado")
    return CatalogExerciseDetail(
        **_summary_fields(exercise),
        image_urls=_image_urls(exercise),
        description=exercise.description,
        instructions=list(exercise.instructions),
    )
