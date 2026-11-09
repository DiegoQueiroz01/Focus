"""Base de alimentos (somente leitura), carregada de app/data/foods.json.

O arquivo é gerado por scripts/alimentos/gerar_alimentos.py a partir da TACO.
Valores sempre por 100 g.
"""

import json
import unicodedata
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

FOODS_FILE = Path(__file__).parent / "data" / "foods.json"

# Palavras que indicam o alimento já pronto para comer: aparecem antes do "cru" na busca.
_PRONTO = ("cozid", "grelhad", "assad", "frit", "refogad")


@dataclass(frozen=True)
class Portion:
    label: str
    grams: float


@dataclass(frozen=True)
class Food:
    id: str
    name: str
    category: str
    kcal: float
    protein: float
    carbs: float
    fat: float
    fiber: float
    sodium_mg: float
    portions: tuple[Portion, ...]
    search_key: str


def normalize(text: str) -> str:
    sem_acento = unicodedata.normalize("NFKD", text).encode("ascii", "ignore").decode()
    return " ".join(sem_acento.lower().replace(",", " ").replace("/", " ").split())


@lru_cache
def foods_by_id() -> dict[str, Food]:
    raw = json.loads(FOODS_FILE.read_text(encoding="utf-8"))
    return {
        item["id"]: Food(
            id=item["id"],
            name=item["name"],
            category=item["category"],
            kcal=item["kcal"],
            protein=item["protein"],
            carbs=item["carbs"],
            fat=item["fat"],
            fiber=item["fiber"],
            sodium_mg=item.get("sodium_mg", 0),
            portions=tuple(Portion(p["label"], p["grams"]) for p in item.get("portions", [])),
            search_key=normalize(item["name"]),
        )
        for item in raw
    }


def matches(search_key: str, terms: list[str]) -> bool:
    """Cada termo precisa ser o começo de alguma palavra do nome ("fran grel" acha frango grelhado)."""
    words = search_key.split()
    return all(any(word.startswith(term) for word in words) for term in terms)


def search_foods(query: str, limit: int = 30) -> list[Food]:
    terms = normalize(query).split()
    if not terms:
        return []

    def rank(food: Food) -> tuple:
        return (
            not food.search_key.startswith(terms[0]),
            not any(p in food.search_key for p in _PRONTO),
            "cru" in food.search_key.split(),
            len(food.name),
        )

    found = [f for f in foods_by_id().values() if matches(f.search_key, terms)]
    return sorted(found, key=rank)[:limit]
