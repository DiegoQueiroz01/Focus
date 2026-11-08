from datetime import datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field


class WorkoutType(str, Enum):
    strength = "strength"
    cardio = "cardio"
    other = "other"


class MuscleGroup(str, Enum):
    chest = "chest"
    back = "back"
    shoulders = "shoulders"
    biceps = "biceps"
    triceps = "triceps"
    forearms = "forearms"
    traps = "traps"
    lower_back = "lower_back"
    abs = "abs"
    quadriceps = "quadriceps"
    hamstrings = "hamstrings"
    glutes = "glutes"
    adductors = "adductors"
    abductors = "abductors"
    calves = "calves"
    neck = "neck"
    full_body = "full_body"
    cardio = "cardio"
    other = "other"


class ExerciseWrite(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    muscle_group: MuscleGroup = MuscleGroup.other
    # Exercício do catálogo de origem (para mostrar foto e músculos). Nulo se criado à mão.
    catalog_id: str | None = Field(default=None, max_length=100)
    sets: int = Field(ge=0, le=100)
    reps: int = Field(default=0, ge=0, le=1000)
    weight_kg: float = Field(default=0, ge=0, le=9999.99)


class ExerciseRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    muscle_group: MuscleGroup
    catalog_id: str | None
    sets: int
    reps: int
    weight_kg: float


class WorkoutWrite(BaseModel):
    """Usado tanto para criar (POST) quanto para substituir (PUT) um treino."""

    name: str = Field(min_length=1, max_length=120)
    type: WorkoutType = WorkoutType.strength
    exercises: list[ExerciseWrite] = Field(default_factory=list, max_length=50)


class WorkoutRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    type: WorkoutType
    created_at: datetime
    total_sets: int
    exercises: list[ExerciseRead]


class WorkoutPage(BaseModel):
    items: list[WorkoutRead]
    total: int
    offset: int
    limit: int
    has_more: bool
