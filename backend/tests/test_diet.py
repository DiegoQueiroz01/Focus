import datetime as dt

import pytest

from app.foods import search_foods
from app.gps import GpsActivityType, estimate_calories
from app.nutrition import ActivityLevel, Goal, GoalPace, Sex, age_on, bmr_mifflin, compute_plan

TODAY = dt.date.today()


def _birth(age: int) -> str:
    return TODAY.replace(year=TODAY.year - age, day=1).isoformat()


def _profile(**fields) -> dict:
    return {
        "sex": "male",
        "birth_date": _birth(30),
        "height_cm": 180,
        "activity_level": "moderate",
        "goal": "lose",
        "goal_pace": "moderate",
        "weight_kg": 90,
        "weight_date": TODAY.isoformat(),
        **fields,
    }


# --- Cálculos


def test_mifflin_st_jeor_reference_values():
    # Exemplo clássico: homem, 80 kg, 180 cm, 30 anos → 1780 kcal.
    assert bmr_mifflin(Sex.MALE, 80, 180, 30) == pytest.approx(1780)
    assert bmr_mifflin(Sex.FEMALE, 60, 165, 30) == pytest.approx(1320.25)


def test_age_on_counts_birthday():
    assert age_on(dt.date(2000, 11, 10), dt.date(2026, 11, 9)) == 25
    assert age_on(dt.date(2000, 11, 9), dt.date(2026, 11, 9)) == 26


def test_plan_lose_maintain_gain():
    base = dict(sex=Sex.MALE, age=30, height_cm=180, weight_kg=80, activity=ActivityLevel.MODERATE)
    maintain = compute_plan(**base, goal=Goal.MAINTAIN)
    lose = compute_plan(**base, goal=Goal.LOSE, pace=GoalPace.MODERATE)
    gain = compute_plan(**base, goal=Goal.GAIN, pace=GoalPace.MODERATE)

    assert maintain.tdee == round(1780 * 1.55)
    assert maintain.calories == 2760
    assert lose.calories == 2210  # 550 kcal a menos ≈ 0,5 kg/semana
    assert gain.calories == 3030
    assert lose.weekly_change_kg == pytest.approx(-0.5, abs=0.01)

    # Macros fecham com as calorias (diferença só de arredondamento).
    for plan in (maintain, lose, gain):
        total = plan.protein_g * 4 + plan.carbs_g * 4 + plan.fat_g * 9
        assert abs(total - plan.calories) < 15
    assert lose.protein_g == 160  # 2 g/kg no déficit
    assert maintain.protein_g == 128


def test_plan_never_goes_below_safe_minimum():
    plan = compute_plan(
        sex=Sex.FEMALE,
        age=60,
        height_cm=150,
        weight_kg=50,
        activity=ActivityLevel.SEDENTARY,
        goal=Goal.LOSE,
        pace=GoalPace.FAST,
    )
    assert plan.calories >= 1200
    assert plan.limited_by_minimum


def test_custom_calories_override():
    plan = compute_plan(
        sex=Sex.MALE,
        age=30,
        height_cm=180,
        weight_kg=80,
        activity=ActivityLevel.MODERATE,
        goal=Goal.LOSE,
        calorie_override=2000,
    )
    assert plan.calories == 2000 and plan.custom_calories


def test_food_search_ignores_accents_and_prefers_cooked():
    results = search_foods("feijao")
    assert results and all("Feijão" in f.name or "feijão" in f.name.lower() for f in results[:3])
    assert "cozido" in results[0].name

    frango = search_foods("fran grel")
    assert "grelhado" in frango[0].name
    assert any(f.name == "Frango, peito, sem pele, grelhado" for f in frango)
    assert search_foods("") == []


# --- API


def test_profile_starts_incomplete_and_computes_plan(client, auth_headers):
    headers = auth_headers()
    empty = client.get("/profile", headers=headers).json()
    assert empty["complete"] is False and empty["plan"] is None

    saved = client.put("/profile", json=_profile(target_weight_kg=80), headers=headers)
    assert saved.status_code == 200
    body = saved.json()
    assert body["complete"] is True
    assert body["weight_kg"] == 90 and body["age"] == 30
    assert body["plan"]["calories"] < body["plan"]["tdee"]
    assert body["plan"]["weeks_to_target"] == 20

    # Manter peso descarta o ritmo.
    maintain = client.put("/profile", json=_profile(goal="maintain"), headers=headers).json()
    assert maintain["goal_pace"] is None
    assert maintain["plan"]["adjustment_kcal"] == 0


def test_profile_requires_weight_the_first_time(client, auth_headers):
    headers = auth_headers()
    response = client.put("/profile", json=_profile(weight_kg=None), headers=headers)
    assert response.status_code == 400


def test_profile_validation(client, auth_headers):
    headers = auth_headers()
    assert client.put("/profile", json=_profile(height_cm=20), headers=headers).status_code == 422
    assert client.put("/profile", json=_profile(birth_date=_birth(5)), headers=headers).status_code == 422
    assert client.put("/profile", json=_profile(goal="bulk"), headers=headers).status_code == 422


def test_weights_upsert_per_day_and_current_weight(client, auth_headers):
    headers = auth_headers()
    yesterday = (TODAY - dt.timedelta(days=1)).isoformat()
    client.post("/weights", json={"date": yesterday, "weight_kg": 91}, headers=headers)
    client.post("/weights", json={"date": TODAY.isoformat(), "weight_kg": 90.5}, headers=headers)
    client.post("/weights", json={"date": TODAY.isoformat(), "weight_kg": 90.2}, headers=headers)

    weights = client.get("/weights", headers=headers).json()
    assert [w["weight_kg"] for w in weights] == [90.2, 91]
    assert client.get("/profile", headers=headers).json()["weight_kg"] == 90.2

    other = auth_headers("outra@example.com")
    assert client.delete(f"/weights/{weights[0]['id']}", headers=other).status_code == 404
    assert client.delete(f"/weights/{weights[0]['id']}", headers=headers).status_code == 204


def test_gps_calories_use_current_weight(client, auth_headers):
    headers = auth_headers()
    client.post("/weights", json={"date": TODAY.isoformat(), "weight_kg": 100}, headers=headers)
    payload = {
        "activity_type": "run",
        "started_at": "2026-11-08T06:00:00-03:00",
        "finished_at": "2026-11-08T06:31:00-03:00",
        "elapsed_seconds": 1860,
        "moving_seconds": 1800,
        "distance_m": 5000.0,
        "route": [],
    }
    body = client.post("/gps-activities", json=payload, headers=headers).json()
    assert body["calories"] == estimate_calories(GpsActivityType.RUN, 1800, 100)


def test_food_search_and_custom_foods(client, auth_headers):
    headers = auth_headers()
    found = client.get("/foods", params={"q": "arroz cozido"}, headers=headers).json()
    assert found and found[0]["source"] == "taco"
    assert any(p["label"] == "1 colher de sopa" for p in found[0]["portions"])

    # Rótulo: 30 g = 120 kcal / 24 g de proteína → por 100 g: 400 kcal / 80 g.
    created = client.post(
        "/foods/custom",
        json={"name": "  Whey   da marca ", "serving_grams": 30, "serving_label": "1 scoop", "kcal": 120, "protein": 24},
        headers=headers,
    )
    assert created.status_code == 201
    food = created.json()
    assert food["name"] == "Whey da marca" and food["kcal"] == 400 and food["protein"] == 80
    assert food["portions"] == [{"label": "1 scoop", "grams": 30}]

    mine = client.get("/foods", params={"q": "whey"}, headers=headers).json()
    assert mine[0]["id"] == food["id"]

    # Outro usuário não vê o alimento personalizado.
    other = auth_headers("outra@example.com")
    assert client.get(f"/foods/{food['id']}", headers=other).status_code == 404
    assert all(f["source"] != "custom" for f in client.get("/foods", params={"q": "whey"}, headers=other).json())


def test_diary_entries_and_day_totals(client, auth_headers):
    headers = auth_headers()
    client.put("/profile", json=_profile(), headers=headers)
    day = TODAY.isoformat()

    arroz = client.post(
        "/diet/entries",
        json={"date": day, "meal": "lunch", "food_id": "taco:3", "grams": 200, "portion_label": None},
        headers=headers,
    )
    assert arroz.status_code == 201
    assert arroz.json()["totals"]["kcal"] == 256  # 128 kcal/100 g

    frango = client.post(
        "/diet/entries",
        json={"date": day, "meal": "lunch", "food_id": "taco:410", "grams": 150},
        headers=headers,
    ).json()
    client.post(
        "/diet/entries", json={"date": day, "meal": "breakfast", "food_id": "taco:488", "grams": 100}, headers=headers
    )

    diary = client.get(f"/diet/days/{day}", headers=headers).json()
    assert [m["meal"] for m in diary["meals"]] == [
        "breakfast", "morning_snack", "lunch", "afternoon_snack", "dinner", "supper",
    ]
    lunch = diary["meals"][2]
    assert len(lunch["entries"]) == 2
    assert lunch["totals"]["protein"] == pytest.approx(5.0 + 48.0)
    assert diary["totals"]["kcal"] == 256 + round(159 * 1.5) + 146
    assert diary["plan"]["calories"] > 0

    updated = client.put(
        f"/diet/entries/{frango['id']}", json={"grams": 100, "meal": "dinner"}, headers=headers
    ).json()
    assert updated["meal"] == "dinner" and updated["totals"]["kcal"] == 159

    summary = client.get("/diet/summary", params={"start": day, "end": day}, headers=headers).json()
    assert summary == [
        {"date": day, "kcal": 256 + 159 + 146, "protein": pytest.approx(5.0 + 32 + 13.3), "carbs": pytest.approx(56.2 + 0.6), "fat": pytest.approx(0.4 + 2.5 + 9.5)}
    ]

    recent = client.get("/foods", headers=headers).json()
    assert [f["id"] for f in recent] == ["taco:488", "taco:410", "taco:3"]

    other = auth_headers("outra@example.com")
    assert client.delete(f"/diet/entries/{frango['id']}", headers=other).status_code == 404
    assert client.delete(f"/diet/entries/{frango['id']}", headers=headers).status_code == 204
    assert client.post(
        "/diet/entries", json={"date": day, "meal": "lunch", "food_id": "taco:999999", "grams": 10}, headers=headers
    ).status_code == 404
