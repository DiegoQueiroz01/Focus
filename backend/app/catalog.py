"""Catálogo de exercícios (somente leitura), carregado de app/data/exercise_catalog.json.

O arquivo é gerado por scripts/catalogo/gerar_catalogo.py. Os nomes de músculos seguem
o vocabulário da base free-exercise-db ("chest", "middle back"...); o app usa esses
mesmos nomes para pintar o desenho do corpo.
"""

import json
import unicodedata
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

from app.schemas.workout import MuscleGroup

CATALOG_FILE = Path(__file__).parent / "data" / "exercise_catalog.json"

# Músculo da base → grupo muscular usado nos treinos e no filtro.
MUSCLE_TO_GROUP: dict[str, MuscleGroup] = {
    "abdominals": MuscleGroup.abs,
    "abductors": MuscleGroup.abductors,
    "adductors": MuscleGroup.adductors,
    "biceps": MuscleGroup.biceps,
    "calves": MuscleGroup.calves,
    "chest": MuscleGroup.chest,
    "forearms": MuscleGroup.forearms,
    "glutes": MuscleGroup.glutes,
    "hamstrings": MuscleGroup.hamstrings,
    "lats": MuscleGroup.back,
    "lower back": MuscleGroup.lower_back,
    "middle back": MuscleGroup.back,
    "neck": MuscleGroup.neck,
    "quadriceps": MuscleGroup.quadriceps,
    "shoulders": MuscleGroup.shoulders,
    "traps": MuscleGroup.traps,
    "triceps": MuscleGroup.triceps,
}


# Exercícios mais comuns em academias brasileiras: aparecem primeiro na lista e na busca,
# nesta ordem. O restante vem em ordem alfabética.
POPULAR_IDS: tuple[str, ...] = tuple(
    """
    Barbell_Bench_Press_-_Medium_Grip Barbell_Incline_Bench_Press_-_Medium_Grip Dumbbell_Bench_Press
    Incline_Dumbbell_Press Dumbbell_Flyes Incline_Dumbbell_Flyes Cable_Crossover Butterfly Pushups
    Dips_-_Chest_Version Decline_Barbell_Bench_Press Machine_Bench_Press
    Pullups Wide-Grip_Lat_Pulldown Close-Grip_Front_Lat_Pulldown V-Bar_Pulldown Seated_Cable_Rows
    Bent_Over_Barbell_Row One-Arm_Dumbbell_Row T-Bar_Row_with_Handle Straight-Arm_Pulldown Chin-Up
    Dumbbell_Shoulder_Press Barbell_Shoulder_Press Arnold_Dumbbell_Press Side_Lateral_Raise
    Front_Dumbbell_Raise Reverse_Flyes Face_Pull Upright_Barbell_Row Machine_Shoulder_Military_Press
    Barbell_Curl Dumbbell_Bicep_Curl Hammer_Curls Preacher_Curl Concentration_Curls EZ-Bar_Curl
    Incline_Dumbbell_Curl Dumbbell_Alternate_Bicep_Curl
    Triceps_Pushdown Triceps_Pushdown_-_Rope_Attachment Lying_Triceps_Press EZ-Bar_Skullcrusher
    Standing_Dumbbell_Triceps_Extension Bench_Dips Close-Grip_Barbell_Bench_Press Tricep_Dumbbell_Kickback
    Dips_-_Triceps_Version
    Barbell_Squat Barbell_Full_Squat Leg_Press Leg_Extensions Lying_Leg_Curls Seated_Leg_Curl
    Romanian_Deadlift Stiff-Legged_Barbell_Deadlift Barbell_Lunge Dumbbell_Lunges Goblet_Squat Hack_Squat
    Barbell_Hip_Thrust Barbell_Glute_Bridge Split_Squat_with_Dumbbells Thigh_Adductor Thigh_Abductor
    Standing_Calf_Raises Seated_Calf_Raise Barbell_Deadlift Sumo_Deadlift Front_Barbell_Squat
    Crunches Plank Hanging_Leg_Raise Reverse_Crunch Russian_Twist Cable_Crunch Ab_Roller Side_Bridge
    Mountain_Climbers
    Barbell_Shrug Dumbbell_Shrug Hyperextensions_Back_Extensions Superman
    Palms-Up_Barbell_Wrist_Curl_Over_A_Bench Farmers_Walk
    Running_Treadmill Walking_Treadmill Bicycling_Stationary Elliptical_Trainer Rowing_Stationary
    Rope_Jumping Stairmaster extra-corrida-rua extra-caminhada extra-natacao extra-spinning extra-hiit
    """.split()
)


def normalize(text: str) -> str:
    """Minúsculas e sem acentos: "triceps" encontra "Tríceps"."""
    decomposed = unicodedata.normalize("NFKD", text.lower())
    return "".join(c for c in decomposed if not unicodedata.combining(c))


@dataclass(frozen=True)
class CatalogExercise:
    id: str
    name: str
    name_en: str | None
    type: str
    primary_muscles: tuple[str, ...]
    secondary_muscles: tuple[str, ...]
    equipment: str | None
    level: str | None
    images: tuple[str, ...]
    icon: str | None
    description: str | None
    instructions: tuple[str, ...]
    search_text: str

    @property
    def muscle_group(self) -> MuscleGroup:
        if self.type == "cardio":
            return MuscleGroup.cardio
        if self.primary_muscles:
            return MUSCLE_TO_GROUP.get(self.primary_muscles[0], MuscleGroup.other)
        return MuscleGroup.other

    @property
    def groups(self) -> set[MuscleGroup]:
        """Grupos dos músculos principais, usados no filtro."""
        return {MUSCLE_TO_GROUP[m] for m in self.primary_muscles if m in MUSCLE_TO_GROUP}


@lru_cache
def load_catalog() -> tuple[CatalogExercise, ...]:
    raw = json.loads(CATALOG_FILE.read_text(encoding="utf-8"))["exercises"]
    exercises = [
        CatalogExercise(
            id=item["id"],
            name=item["name"],
            name_en=item["name_en"],
            type=item["type"],
            primary_muscles=tuple(item["primary_muscles"]),
            secondary_muscles=tuple(item["secondary_muscles"]),
            equipment=item["equipment"],
            level=item["level"],
            images=tuple(item["images"]),
            icon=item["icon"],
            description=item["description"],
            instructions=tuple(item["instructions"]),
            search_text=normalize(f"{item['name']} {item['name_en'] or ''}"),
        )
        for item in raw
    ]
    popularity = {exercise_id: rank for rank, exercise_id in enumerate(POPULAR_IDS)}
    exercises.sort(key=lambda e: (popularity.get(e.id, len(popularity)), normalize(e.name)))
    return tuple(exercises)


@lru_cache
def catalog_by_id() -> dict[str, CatalogExercise]:
    return {e.id: e for e in load_catalog()}


def search_catalog(
    query: str | None = None,
    exercise_type: str | None = None,
    group: MuscleGroup | None = None,
) -> list[CatalogExercise]:
    terms = normalize(query).split() if query else []
    return [
        e
        for e in load_catalog()
        if (exercise_type is None or e.type == exercise_type)
        and (group is None or group in e.groups)
        and all(term in e.search_text for term in terms)
    ]
