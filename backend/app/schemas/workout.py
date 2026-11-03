from datetime import datetime
from enum import Enum

from pydantic import BaseModel, ConfigDict, Field


class WorkoutType(str, Enum):
    strength = "strength"
    cardio = "cardio"
    other = "other"


class ExerciseCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    sets: int = Field(ge=0, le=100)
    reps: int = Field(default=0, ge=0, le=1000)
    weight_kg: float = Field(default=0, ge=0, le=9999.99)


class ExerciseRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    sets: int
    reps: int
    weight_kg: float


class WorkoutCreate(BaseModel):
    name: str = Field(min_length=1, max_length=120)
    type: WorkoutType = WorkoutType.strength
    performed_at: datetime | None = None
    duration_minutes: int = Field(default=0, ge=0, le=24 * 60)
    exercises: list[ExerciseCreate] = Field(default_factory=list, max_length=50)


class WorkoutRead(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: int
    name: str
    type: WorkoutType
    performed_at: datetime
    duration_minutes: int
    total_sets: int
    exercises: list[ExerciseRead]


class WorkoutPage(BaseModel):
    items: list[WorkoutRead]
    total: int
    offset: int
    limit: int
    has_more: bool
