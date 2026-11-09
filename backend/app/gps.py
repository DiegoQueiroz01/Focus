"""Regras das atividades por GPS: tipos aceitos, calorias e prévia do trajeto."""

from enum import Enum

# Peso usado nas calorias quando o usuário ainda não registrou o dele.
PESO_PADRAO_KG = 70.0


class GpsActivityType(str, Enum):
    RUN = "run"
    WALK = "walk"
    TRAIL_RUN = "trail_run"
    HIKE = "hike"
    RIDE = "ride"
    MOUNTAIN_BIKE = "mountain_bike"
    INLINE_SKATE = "inline_skate"


# MET médio de cada atividade (Compendium of Physical Activities).
MET = {
    GpsActivityType.RUN: 9.8,
    GpsActivityType.WALK: 3.5,
    GpsActivityType.TRAIL_RUN: 10.0,
    GpsActivityType.HIKE: 6.0,
    GpsActivityType.RIDE: 7.5,
    GpsActivityType.MOUNTAIN_BIKE: 8.5,
    GpsActivityType.INLINE_SKATE: 7.5,
}


# Músculos que cada atividade trabalha (principais, secundários), no vocabulário do catálogo.
MUSCLES: dict[GpsActivityType, tuple[tuple[str, ...], tuple[str, ...]]] = {
    GpsActivityType.RUN: (("quadriceps", "hamstrings", "glutes", "calves"), ("abdominals",)),
    GpsActivityType.WALK: (("quadriceps", "glutes", "calves"), ("hamstrings",)),
    GpsActivityType.TRAIL_RUN: (
        ("quadriceps", "hamstrings", "glutes", "calves"),
        ("abdominals", "adductors", "abductors"),
    ),
    GpsActivityType.HIKE: (("quadriceps", "glutes", "calves"), ("hamstrings", "lower back")),
    GpsActivityType.RIDE: (("quadriceps", "glutes"), ("hamstrings", "calves")),
    GpsActivityType.MOUNTAIN_BIKE: (
        ("quadriceps", "glutes"),
        ("hamstrings", "calves", "abdominals", "forearms"),
    ),
    GpsActivityType.INLINE_SKATE: (
        ("quadriceps", "glutes", "abductors", "adductors"),
        ("hamstrings", "calves", "abdominals"),
    ),
}

# Minutos em movimento que valem uma "série" no desenho do corpo. A caminhada é mais
# leve, então precisa de mais tempo para contar o mesmo.
MINUTES_PER_SET = {
    GpsActivityType.RUN: 5,
    GpsActivityType.WALK: 10,
    GpsActivityType.TRAIL_RUN: 5,
    GpsActivityType.HIKE: 8,
    GpsActivityType.RIDE: 6,
    GpsActivityType.MOUNTAIN_BIKE: 5,
    GpsActivityType.INLINE_SKATE: 6,
}

# Limite por atividade, para um pedal de 4 h não apagar o resto da semana no desenho.
MAX_SETS_PER_ACTIVITY = 12
SECONDARY_WEIGHT = 0.5


def muscle_load(activity_type: GpsActivityType | str, moving_seconds: int) -> dict[str, float]:
    """Séries equivalentes por músculo, na mesma escala dos treinos (ver app/muscle_load.py)."""
    try:
        kind = GpsActivityType(activity_type)
    except ValueError:
        return {}
    sets = min(moving_seconds / 60 / MINUTES_PER_SET[kind], MAX_SETS_PER_ACTIVITY)
    if sets <= 0:
        return {}
    primary, secondary = MUSCLES[kind]
    load = {muscle: sets for muscle in primary}
    load.update({muscle: sets * SECONDARY_WEIGHT for muscle in secondary})
    return {muscle: round(value, 1) for muscle, value in sorted(load.items())}


def estimate_calories(
    activity_type: GpsActivityType, moving_seconds: int, weight_kg: float = PESO_PADRAO_KG
) -> int:
    return round(MET[activity_type] * weight_kg * moving_seconds / 3600)


def route_preview(route: list[list[float | None]], max_points: int = 80) -> list[list[float]]:
    """Amostra o trajeto em até `max_points` pontos [lat, lon] para os mini mapas."""
    if len(route) <= max_points:
        return [[p[0], p[1]] for p in route]
    step = (len(route) - 1) / (max_points - 1)
    return [[route[round(i * step)][0], route[round(i * step)][1]] for i in range(max_points)]
