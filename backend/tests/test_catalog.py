from app.catalog import MUSCLE_TO_GROUP, POPULAR_IDS, catalog_by_id, load_catalog


def test_catalog_file_is_consistent():
    catalog = load_catalog()
    assert len(catalog) > 900
    assert len({e.id for e in catalog}) == len(catalog)
    for exercise in catalog:
        assert exercise.name and exercise.type in {"strength", "cardio", "other"}
        assert set(exercise.primary_muscles) <= set(MUSCLE_TO_GROUP)
        assert set(exercise.secondary_muscles) <= set(MUSCLE_TO_GROUP)
        # Toda entrada tem uma ilustração: foto da base ou ícone.
        assert exercise.images or exercise.icon


def test_popular_exercises_come_first():
    assert set(POPULAR_IDS) <= set(catalog_by_id())
    first = [e.id for e in load_catalog()[:3]]
    assert first == list(POPULAR_IDS[:3])


def test_catalog_requires_login(client):
    assert client.get("/catalog/exercises").status_code == 401


def test_catalog_search_ignores_accents_and_searches_both_languages(client, auth_headers):
    headers = auth_headers()
    supino = client.get("/catalog/exercises", params={"q": "supino"}, headers=headers).json()
    assert supino["items"][0]["name"] == "Supino reto com barra"

    pt = client.get("/catalog/exercises", params={"q": "triceps corda"}, headers=headers).json()
    assert "Tríceps corda" in [e["name"] for e in pt["items"]]

    en = client.get("/catalog/exercises", params={"q": "bench press"}, headers=headers).json()
    assert en["total"] > 5
    assert all("bench" in e["name_en"].lower() for e in en["items"])


def test_catalog_filters_by_type_and_muscle_group(client, auth_headers):
    headers = auth_headers()
    chest = client.get(
        "/catalog/exercises",
        params={"type": "strength", "muscle_group": "chest", "limit": 100},
        headers=headers,
    ).json()
    assert chest["total"] > 20
    assert all(e["type"] == "strength" and "chest" in e["primary_muscles"] for e in chest["items"])

    back = client.get("/catalog/exercises", params={"muscle_group": "back", "limit": 100}, headers=headers).json()
    assert all({"lats", "middle back"} & set(e["primary_muscles"]) for e in back["items"])

    cardio = client.get("/catalog/exercises", params={"type": "cardio", "limit": 100}, headers=headers).json()
    names = [e["name"] for e in cardio["items"]]
    assert {"Natação", "Corrida na esteira", "Pular corda"} <= set(names)
    assert all(e["muscle_group"] == "cardio" for e in cardio["items"])


def test_catalog_pagination(client, auth_headers):
    headers = auth_headers()
    first = client.get("/catalog/exercises", params={"limit": 10}, headers=headers).json()
    second = client.get("/catalog/exercises", params={"limit": 10, "offset": 10}, headers=headers).json()
    assert first["has_more"] and len(first["items"]) == 10
    assert not {e["id"] for e in first["items"]} & {e["id"] for e in second["items"]}


def test_catalog_detail(client, auth_headers):
    headers = auth_headers()
    detail = client.get("/catalog/exercises/Barbell_Bench_Press_-_Medium_Grip", headers=headers).json()
    assert detail["name"] == "Supino reto com barra"
    assert detail["muscle_group"] == "chest"
    assert len(detail["image_urls"]) == 2
    assert detail["image_urls"][0].startswith("https://") and detail["image_urls"][0].endswith(".jpg")
    assert detail["instructions"]

    extra = client.get("/catalog/exercises/extra-natacao", headers=headers).json()
    assert extra["image_url"] is None and extra["icon"] == "pool" and extra["description"]

    assert client.get("/catalog/exercises/nao-existe", headers=headers).status_code == 404


def test_workout_exercise_keeps_catalog_link(client, auth_headers):
    headers = auth_headers()
    payload = {
        "name": "Peito",
        "exercises": [
            {"name": "Supino reto com barra", "muscle_group": "chest", "catalog_id": "Barbell_Bench_Press_-_Medium_Grip", "sets": 4, "reps": 10, "weight_kg": 40},
            {"name": "Exercício livre", "muscle_group": "traps", "sets": 3},
        ],
    }
    created = client.post("/workouts", json=payload, headers=headers)
    assert created.status_code == 201
    exercises = created.json()["exercises"]
    assert exercises[0]["catalog_id"] == "Barbell_Bench_Press_-_Medium_Grip"
    assert exercises[1]["catalog_id"] is None and exercises[1]["muscle_group"] == "traps"

    payload["exercises"][0]["catalog_id"] = "inventado"
    assert client.post("/workouts", json=payload, headers=headers).status_code == 422
