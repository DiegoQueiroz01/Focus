"""Gera app/data/foods.json a partir da TACO (Tabela Brasileira de Composição de Alimentos).

Fonte: TACO 4ª edição (NEPA/Unicamp), na versão organizada em CSV pelo projeto
https://github.com/raulfdm/taco-api (licença MIT), fixada no commit abaixo.

Também acrescenta:
- extras.json: alimentos comuns que a TACO não tem (ex.: whey, macarrão cozido),
  com valores da USDA FoodData Central;
- porcoes.json: medidas caseiras aproximadas ("1 unidade", "1 colher de sopa"...),
  aplicadas aos alimentos cujo nome casa com a expressão regular da regra.

Uso (na pasta backend):  python scripts/alimentos/gerar_alimentos.py
"""

import csv
import io
import json
import re
import urllib.request
from pathlib import Path

COMMIT = "06e466ad2f3d76064b587808b1804564b2c40f67"
BASE = f"https://raw.githubusercontent.com/raulfdm/taco-api/{COMMIT}/references/csv"

AQUI = Path(__file__).parent
SAIDA = AQUI.parents[1] / "app" / "data" / "foods.json"


def baixar_csv(nome: str) -> list[dict[str, str]]:
    with urllib.request.urlopen(f"{BASE}/{nome}.csv", timeout=60) as resposta:
        texto = resposta.read().decode("utf-8")
    return list(csv.DictReader(io.StringIO(texto)))


def numero(valor: str | None) -> float:
    try:
        return round(float(valor), 1) if valor not in (None, "") else 0.0
    except ValueError:
        return 0.0


def main() -> None:
    categorias = {c["id"]: c["name"] for c in baixar_csv("categories")}
    nutrientes = {n["foodId"]: n for n in baixar_csv("nutrients")}
    regras = [
        (re.compile(r["padrao"], re.IGNORECASE), r["porcoes"])
        for r in json.loads((AQUI / "porcoes.json").read_text(encoding="utf-8"))
    ]

    alimentos = []
    for comida in baixar_csv("food"):
        n = nutrientes.get(comida["id"], {})
        alimentos.append(
            {
                "id": f"taco:{comida['id']}",
                "name": " ".join(comida["name"].split()),
                "category": categorias.get(comida["categoryId"], "Outros"),
                "kcal": numero(n.get("kcal")),
                "protein": numero(n.get("protein")),
                "carbs": numero(n.get("carbohydrates")),
                "fat": numero(n.get("lipids")),
                "fiber": numero(n.get("dietaryFiber")),
                "sodium_mg": numero(n.get("sodium")),
            }
        )
    alimentos.extend(json.loads((AQUI / "extras.json").read_text(encoding="utf-8")))

    for alimento in alimentos:
        alimento.setdefault("portions", [])
        for padrao, porcoes in regras:
            if padrao.search(alimento["name"]):
                alimento["portions"] = porcoes
                break

    SAIDA.write_text(json.dumps(alimentos, ensure_ascii=False, indent=1), encoding="utf-8")
    print(f"{len(alimentos)} alimentos gravados em {SAIDA}")


if __name__ == "__main__":
    main()
