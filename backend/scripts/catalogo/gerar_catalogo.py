"""Gera app/data/exercise_catalog.json a partir das fontes abertas.

Fontes:
- free-exercise-db (https://github.com/yuhonas/free-exercise-db), domínio público
  (The Unlicense). Fixado no commit abaixo para que as imagens não mudem.
- nomes_pt.json: tradução dos nomes para português.
- instrucoes_pt.json: tradução do passo a passo (frase em inglês → português).
- extras.json: atividades de cardio e outras que não existem na base acima.

Uso (na pasta backend/):
    python scripts/catalogo/gerar_catalogo.py
"""

import json
import urllib.request
from pathlib import Path

FREE_EXERCISE_DB_COMMIT = "f00c92c7dcf1216a928a52c3706c7ce8e2f71ed5"
FONTE_URL = (
    f"https://cdn.jsdelivr.net/gh/yuhonas/free-exercise-db@{FREE_EXERCISE_DB_COMMIT}"
    "/dist/exercises.json"
)

PASTA = Path(__file__).parent
SAIDA = PASTA.parents[1] / "app" / "data" / "exercise_catalog.json"

TIPO_POR_CATEGORIA = {
    "strength": "strength",
    "powerlifting": "strength",
    "olympic weightlifting": "strength",
    "strongman": "strength",
    "cardio": "cardio",
    "plyometrics": "other",
    "stretching": "other",
}

EQUIPAMENTO_PT = {
    "bands": "Elástico",
    "barbell": "Barra",
    "body only": "Peso corporal",
    "cable": "Cabo / polia",
    "dumbbell": "Halteres",
    "e-z curl bar": "Barra W",
    "exercise ball": "Bola suíça",
    "foam roll": "Rolo de liberação",
    "kettlebells": "Kettlebell",
    "machine": "Máquina",
    "medicine ball": "Medicine ball",
    "other": "Outro",
}


def carregar_base() -> list[dict]:
    with urllib.request.urlopen(FONTE_URL, timeout=60) as resposta:
        return json.load(resposta)


def main() -> None:
    base = carregar_base()
    nomes_pt = json.loads((PASTA / "nomes_pt.json").read_text(encoding="utf-8"))
    instrucoes_pt = json.loads((PASTA / "instrucoes_pt.json").read_text(encoding="utf-8"))
    extras = json.loads((PASTA / "extras.json").read_text(encoding="utf-8"))

    catalogo = []
    for item in base:
        catalogo.append(
            {
                "id": item["id"],
                "name": nomes_pt[item["name"]],
                "name_en": item["name"],
                "type": TIPO_POR_CATEGORIA[item["category"]],
                "primary_muscles": item["primaryMuscles"],
                "secondary_muscles": item["secondaryMuscles"],
                "equipment": EQUIPAMENTO_PT.get(item["equipment"] or ""),
                "level": item["level"],
                "images": item["images"],
                # Poucos itens da base vêm sem foto; esses usam um ícone genérico.
                "icon": None if item["images"] else "fitness",
                "description": None,
                "instructions": [instrucoes_pt[passo.strip()] for passo in item["instructions"] if passo.strip()],
            }
        )

    for item in extras:
        catalogo.append(
            {
                "id": item["id"],
                "name": item["name"],
                "name_en": None,
                "type": item["type"],
                "primary_muscles": item["primary"],
                "secondary_muscles": item["secondary"],
                "equipment": None,
                "level": None,
                "images": [],
                "icon": item["icon"],
                "description": item["description"],
                "instructions": [],
            }
        )

    SAIDA.parent.mkdir(parents=True, exist_ok=True)
    SAIDA.write_text(
        json.dumps(
            {"source_commit": FREE_EXERCISE_DB_COMMIT, "exercises": catalogo},
            ensure_ascii=False,
            separators=(",", ":"),
        ),
        encoding="utf-8",
    )
    print(f"{len(catalogo)} exercícios gravados em {SAIDA}")


if __name__ == "__main__":
    main()
