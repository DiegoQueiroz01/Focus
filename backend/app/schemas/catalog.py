from pydantic import BaseModel

from app.schemas.workout import MuscleGroup, WorkoutType


class CatalogExerciseSummary(BaseModel):
    id: str
    name: str
    name_en: str | None
    type: WorkoutType
    muscle_group: MuscleGroup
    primary_muscles: list[str]
    secondary_muscles: list[str]
    equipment: str | None
    level: str | None
    # URL completa da primeira foto (posição inicial). Nulo nas atividades sem foto,
    # que usam `icon` como ilustração.
    image_url: str | None
    icon: str | None


class CatalogExerciseDetail(CatalogExerciseSummary):
    image_urls: list[str]
    description: str | None
    # Passo a passo; disponível em inglês na base de origem.
    instructions: list[str]


class CatalogPage(BaseModel):
    items: list[CatalogExerciseSummary]
    total: int
    offset: int
    limit: int
    has_more: bool
