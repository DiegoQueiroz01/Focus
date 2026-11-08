from datetime import datetime

from pydantic import BaseModel, ConfigDict, Field

from app.schemas.workout import MuscleGroup, WorkoutType


class SessionFinish(BaseModel):
    total_volume_kg: float = Field(default=0, ge=0, le=10_000_000)
    total_sets: int = Field(default=0, ge=0, le=5_000)
    last_muscle_group: MuscleGroup | None = None


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
