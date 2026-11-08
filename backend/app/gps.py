"""Regras das atividades por GPS: tipos aceitos, calorias e prévia do trajeto."""

from enum import Enum

# Peso usado nas calorias enquanto o perfil não guarda o peso do usuário.
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
