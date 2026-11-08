from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field, field_validator

from app.schemas.workout import MuscleGroup, WorkoutType


class CompletedSets(BaseModel):
    exercise_id: int
    sets: int = Field(ge=0, le=100)


class SessionFinish(BaseModel):
    total_volume_kg: float = Field(default=0, ge=0, le=10_000_000)
    total_sets: int = Field(default=0, ge=0, le=5_000)
    last_muscle_group: MuscleGroup | None = None
    # Séries concluídas de cada exercício do treino, para calcular os músculos trabalhados.
    completed_sets: list[CompletedSets] = Field(default_factory=list, max_length=50)


class SessionRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    workout_id: int | None
    workout_name: str
    workout_type: WorkoutType
    started_at: datetime
    finished_at: datetime | None
    is_active: bool
    duration_seconds: int
    total_volume_kg: float
    total_sets: int
    last_muscle_group: MuscleGroup | None
    muscle_load: dict[str, float]

    @field_validator("muscle_load", mode="before")
    @classmethod
    def _empty_when_missing(cls, value: dict[str, float] | None) -> dict[str, float]:
        return value or {}
