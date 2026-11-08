"""Quanto cada músculo foi trabalhado em uma sessão, medido em séries.

Cada série concluída vale 1 para os músculos principais do exercício e 0,5 para os
secundários. Exercícios do catálogo usam os músculos dele; os criados à mão usam o
grupo muscular escolhido pelo usuário.
"""

from collections import defaultdict
from collections.abc import Iterable, Mapping

from app.catalog import catalog_by_id
from app.models import Exercise
from app.schemas.workout import MuscleGroup

SECONDARY_WEIGHT = 0.5

# Grupo escolhido à mão → músculos do desenho (mesmo vocabulário do catálogo).
GROUP_TO_MUSCLES: dict[MuscleGroup, tuple[str, ...]] = {
    MuscleGroup.chest: ("chest",),
    MuscleGroup.back: ("lats", "middle back"),
    MuscleGroup.shoulders: ("shoulders",),
    MuscleGroup.biceps: ("biceps",),
    MuscleGroup.triceps: ("triceps",),
    MuscleGroup.forearms: ("forearms",),
    MuscleGroup.traps: ("traps",),
    MuscleGroup.lower_back: ("lower back",),
    MuscleGroup.abs: ("abdominals",),
    MuscleGroup.quadriceps: ("quadriceps",),
    MuscleGroup.hamstrings: ("hamstrings",),
    MuscleGroup.glutes: ("glutes",),
    MuscleGroup.adductors: ("adductors",),
    MuscleGroup.abductors: ("abductors",),
    MuscleGroup.calves: ("calves",),
    MuscleGroup.neck: ("neck",),
    MuscleGroup.full_body: ("chest", "lats", "shoulders", "abdominals", "quadriceps", "glutes"),
    MuscleGroup.cardio: ("quadriceps", "calves"),
}


def compute_muscle_load(
    exercises: Iterable[Exercise], completed_sets: Mapping[int, int]
) -> dict[str, float]:
    catalog = catalog_by_id()
    load: dict[str, float] = defaultdict(float)

    for exercise in exercises:
        sets = completed_sets.get(exercise.id, 0)
        if sets <= 0:
            continue
        entry = catalog.get(exercise.catalog_id) if exercise.catalog_id else None
        if entry is not None:
            for muscle in entry.primary_muscles:
                load[muscle] += sets
            for muscle in entry.secondary_muscles:
                load[muscle] += sets * SECONDARY_WEIGHT
        else:
            try:
                muscles = GROUP_TO_MUSCLES.get(MuscleGroup(exercise.muscle_group), ())
            except ValueError:
                muscles = ()
            for muscle in muscles:
                load[muscle] += sets

    return {muscle: round(value, 1) for muscle, value in sorted(load.items())}


def sum_loads(loads: Iterable[Mapping[str, float] | None]) -> dict[str, float]:
    total: dict[str, float] = defaultdict(float)
    for load in loads:
        for muscle, value in (load or {}).items():
            total[muscle] += value
    return {muscle: round(value, 1) for muscle, value in sorted(total.items())}
