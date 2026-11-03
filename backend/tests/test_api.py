from datetime import datetime, timedelta, timezone


def _workout(name: str, days_ago: int = 0, duration: int = 30, sets: tuple[int, ...] = ()) -> dict:
    performed_at = datetime.now(timezone.utc) - timedelta(days=days_ago)
    return {
        "name": name,
        "type": "strength",
        "performed_at": performed_at.isoformat(),
        "duration_minutes": duration,
        "exercises": [
            {"name": f"Ex {i}", "sets": s, "reps": 10, "weight_kg": 20.5} for i, s in enumerate(sets)
        ],
    }


def test_login_rejects_wrong_password_and_unknown_user(client, make_user):
    make_user("diego", "senha-forte-123")

    assert client.post("/login", json={"username": "diego", "password": "errada"}).status_code == 401
    assert client.post("/login", json={"username": "ninguem", "password": "x"}).status_code == 401

    ok = client.post("/login", json={"username": "diego", "password": "senha-forte-123"})
    assert ok.status_code == 200
    assert ok.json()["token_type"] == "bearer"


def test_protected_routes_require_valid_token(client):
    assert client.get("/workouts").status_code == 401
    assert client.get("/dashboard/summary").status_code == 401
    bad = {"Authorization": "Bearer invalido"}
    assert client.get("/workouts", headers=bad).status_code == 401


def test_create_and_paginate_workouts(client, auth_headers):
    headers = auth_headers()
    for i in range(5):
        created = client.post("/workouts", json=_workout(f"Treino {i}", days_ago=i, sets=(4, 3)), headers=headers)
        assert created.status_code == 201
    assert created.json()["total_sets"] == 7
    assert created.json()["exercises"][0]["weight_kg"] == 20.5

    first = client.get("/workouts", params={"offset": 0, "limit": 2}, headers=headers).json()
    assert [w["name"] for w in first["items"]] == ["Treino 0", "Treino 1"]
    assert first["total"] == 5 and first["has_more"] is True

    last = client.get("/workouts", params={"offset": 4, "limit": 2}, headers=headers).json()
    assert [w["name"] for w in last["items"]] == ["Treino 4"]
    assert last["has_more"] is False


def test_users_only_see_their_own_data(client, auth_headers):
    diego = auth_headers("diego")
    outro = auth_headers("outro")
    client.post("/workouts", json=_workout("Do Diego", sets=(4,)), headers=diego)

    assert client.get("/workouts", headers=outro).json()["total"] == 0
    assert client.get("/dashboard/summary", headers=outro).json()["total_sets"] == 0


def test_dashboard_summary_totals_and_period(client, auth_headers):
    headers = auth_headers()
    client.post("/workouts", json=_workout("Recente", days_ago=1, duration=60, sets=(4, 4)), headers=headers)
    client.post("/workouts", json=_workout("Antigo", days_ago=30, duration=45, sets=(3,)), headers=headers)

    total = client.get("/dashboard/summary", headers=headers).json()
    assert total == {"total_workouts": 2, "total_sets": 11, "total_minutes": 105, "period_days": None}

    week = client.get("/dashboard/summary", params={"days": 7}, headers=headers).json()
    assert week["total_sets"] == 8 and week["total_minutes"] == 60


def test_create_workout_validates_payload(client, auth_headers):
    headers = auth_headers()
    invalid = _workout("X", sets=(-1,))
    assert client.post("/workouts", json=invalid, headers=headers).status_code == 422
    assert client.post("/workouts", json={"name": ""}, headers=headers).status_code == 422
