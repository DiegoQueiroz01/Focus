from datetime import date, datetime, timedelta, timezone

import pytest

from app.api.routes.dashboard import compute_streak
from app.models import WorkoutSession


def _workout(name: str = "Treino A", exercises: tuple[tuple[int, int, float], ...] = ()) -> dict:
    return {
        "name": name,
        "type": "strength",
        "exercises": [
            {"name": f"Ex {i}", "muscle_group": "chest", "sets": s, "reps": r, "weight_kg": w}
            for i, (s, r, w) in enumerate(exercises)
        ],
    }


def _add_session(session_factory, user_id: int, started_at: datetime, **fields) -> None:
    with session_factory() as db:
        db.add(
            WorkoutSession(
                user_id=user_id,
                workout_name=fields.pop("name", "Treino"),
                workout_type="strength",
                started_at=started_at,
                finished_at=started_at + timedelta(seconds=fields.get("duration_seconds", 0)),
                **fields,
            )
        )
        db.commit()


# --- autenticação


def test_register_creates_account_and_logs_in(client):
    response = client.post(
        "/register",
        json={"name": "  Diêgo   Queiroz ", "email": "Diego@Example.com", "password": "senha-forte-123"},
    )
    assert response.status_code == 201
    headers = {"Authorization": f"Bearer {response.json()['access_token']}"}

    me = client.get("/me", headers=headers).json()
    assert me["name"] == "Diêgo Queiroz"
    assert me["email"] == "diego@example.com"

    login = client.post("/login", json={"email": "DIEGO@example.com", "password": "senha-forte-123"})
    assert login.status_code == 200


def test_register_rejects_duplicate_and_invalid_data(client):
    payload = {"name": "Diego", "email": "diego@example.com", "password": "senha-forte-123"}
    assert client.post("/register", json=payload).status_code == 201
    duplicate = client.post("/register", json={**payload, "email": "DIEGO@example.com"})
    assert duplicate.status_code == 409

    assert client.post("/register", json={**payload, "email": "nao-e-email"}).status_code == 400
    assert client.post("/register", json={**payload, "email": "a@b"}).status_code == 400
    assert client.post("/register", json={**payload, "password": "curta"}).status_code == 422
    assert client.post("/register", json={**payload, "name": " "}).status_code == 422


def test_login_rejects_wrong_password_and_unknown_user(client, make_user):
    make_user("diego@example.com")
    assert client.post("/login", json={"email": "diego@example.com", "password": "errada"}).status_code == 401
    assert client.post("/login", json={"email": "ninguem@example.com", "password": "x"}).status_code == 401


def test_legacy_username_login_still_works(client, make_user):
    make_user("legado@example.com", username="diego")
    response = client.post("/login", json={"email": "diego", "password": "senha-forte-123"})
    assert response.status_code == 200


def test_protected_routes_require_valid_token(client):
    for path in ("/workouts", "/sessions", "/dashboard/overview", "/me"):
        assert client.get(path).status_code == 401
    assert client.get("/workouts", headers={"Authorization": "Bearer invalido"}).status_code == 401


# --- treinos (CRUD)


def test_workout_crud(client, auth_headers):
    headers = auth_headers()
    created = client.post("/workouts", json=_workout(exercises=((4, 10, 20.5), (3, 12, 10))), headers=headers)
    assert created.status_code == 201
    body = created.json()
    assert body["total_sets"] == 7
    assert body["exercises"][0]["muscle_group"] == "chest"
    workout_id = body["id"]

    assert client.get(f"/workouts/{workout_id}", headers=headers).json()["name"] == "Treino A"

    updated = client.put(
        f"/workouts/{workout_id}",
        json={
            "name": "Treino B",
            "type": "strength",
            "exercises": [{"name": "Remada", "muscle_group": "back", "sets": 5, "reps": 8, "weight_kg": 40}],
        },
        headers=headers,
    )
    assert updated.status_code == 200
    assert updated.json()["name"] == "Treino B"
    assert [e["name"] for e in updated.json()["exercises"]] == ["Remada"]

    assert client.delete(f"/workouts/{workout_id}", headers=headers).status_code == 204
    assert client.get(f"/workouts/{workout_id}", headers=headers).status_code == 404
    assert client.get("/workouts", headers=headers).json()["total"] == 0


def test_workouts_paginate(client, auth_headers):
    headers = auth_headers()
    for i in range(5):
        client.post("/workouts", json=_workout(f"Treino {i}"), headers=headers)

    first = client.get("/workouts", params={"offset": 0, "limit": 2}, headers=headers).json()
    assert len(first["items"]) == 2 and first["total"] == 5 and first["has_more"] is True
    last = client.get("/workouts", params={"offset": 4, "limit": 2}, headers=headers).json()
    assert len(last["items"]) == 1 and last["has_more"] is False


def test_users_cannot_touch_each_others_data(client, auth_headers):
    diego = auth_headers("diego@example.com")
    outro = auth_headers("outro@example.com")
    workout_id = client.post("/workouts", json=_workout(), headers=diego).json()["id"]
    session_id = client.post(f"/workouts/{workout_id}/sessions", headers=diego).json()["id"]

    assert client.get("/workouts", headers=outro).json()["total"] == 0
    assert client.get(f"/workouts/{workout_id}", headers=outro).status_code == 404
    assert client.put(f"/workouts/{workout_id}", json=_workout(), headers=outro).status_code == 404
    assert client.delete(f"/workouts/{workout_id}", headers=outro).status_code == 404
    assert client.post(f"/workouts/{workout_id}/sessions", headers=outro).status_code == 404
    assert client.post(f"/sessions/{session_id}/finish", json={}, headers=outro).status_code == 404
    assert client.get("/sessions", headers=outro).json() == []


def test_create_workout_validates_payload(client, auth_headers):
    headers = auth_headers()
    assert client.post("/workouts", json=_workout(exercises=((-1, 10, 0),)), headers=headers).status_code == 422
    assert client.post("/workouts", json={"name": ""}, headers=headers).status_code == 422
    bad_group = _workout(exercises=((3, 10, 0),))
    bad_group["exercises"][0]["muscle_group"] = "orelha"
    assert client.post("/workouts", json=bad_group, headers=headers).status_code == 422


# --- sessões


def test_session_lifecycle(client, auth_headers):
    headers = auth_headers()
    workout_id = client.post("/workouts", json=_workout(exercises=((3, 10, 50),)), headers=headers).json()["id"]

    started = client.post(f"/workouts/{workout_id}/sessions", headers=headers)
    assert started.status_code == 201
    session = started.json()
    assert session["is_active"] is True and session["workout_name"] == "Treino A"

    assert client.get("/sessions/active", headers=headers).json()["id"] == session["id"]
    # Só uma sessão aberta por vez.
    assert client.post(f"/workouts/{workout_id}/sessions", headers=headers).status_code == 409

    finished = client.post(
        f"/sessions/{session['id']}/finish",
        json={"total_volume_kg": 1500, "total_sets": 3, "last_muscle_group": "chest"},
        headers=headers,
    )
    assert finished.status_code == 200
    body = finished.json()
    assert body["is_active"] is False
    assert body["total_volume_kg"] == 1500 and body["last_muscle_group"] == "chest"
    assert body["duration_seconds"] >= 0

    assert client.get("/sessions/active", headers=headers).json() is None
    assert client.post(f"/sessions/{session['id']}/finish", json={}, headers=headers).status_code == 409


def test_session_history_survives_workout_deletion(client, auth_headers):
    headers = auth_headers()
    workout_id = client.post("/workouts", json=_workout("Pernas"), headers=headers).json()["id"]
    session_id = client.post(f"/workouts/{workout_id}/sessions", headers=headers).json()["id"]
    client.post(f"/sessions/{session_id}/finish", json={}, headers=headers)

    client.delete(f"/workouts/{workout_id}", headers=headers)
    history = client.get("/sessions", headers=headers).json()
    assert [s["workout_name"] for s in history] == ["Pernas"]


def test_discard_session_and_filter_by_range(client, auth_headers, session_factory, make_user):
    headers = auth_headers()
    user_id = client.get("/me", headers=headers).json()["id"]
    day = datetime(2026, 11, 2, 15, 0, tzinfo=timezone.utc)
    _add_session(session_factory, user_id, day, name="No dia")
    _add_session(session_factory, user_id, day - timedelta(days=1), name="Dia anterior")

    in_range = client.get(
        "/sessions",
        params={"start": "2026-11-02T03:00:00Z", "end": "2026-11-03T03:00:00Z"},
        headers=headers,
    ).json()
    assert [s["workout_name"] for s in in_range] == ["No dia"]

    assert client.delete(f"/sessions/{in_range[0]['id']}", headers=headers).status_code == 204
    assert len(client.get("/sessions", headers=headers).json()) == 1


# --- painel


def test_overview_week_totals_heatmap_and_streak(client, auth_headers, session_factory):
    headers = auth_headers()
    user_id = client.get("/me", headers=headers).json()["id"]
    now = datetime.now(timezone.utc).replace(hour=15, minute=0, second=0, microsecond=0)
    today = now.date()
    monday = today - timedelta(days=today.weekday())

    # Hoje: duas sessões. Ontem: uma. Há 10 dias: uma (fora da sequência).
    _add_session(session_factory, user_id, now, duration_seconds=1800, total_volume_kg=1000, total_sets=10)
    _add_session(session_factory, user_id, now, duration_seconds=600, total_volume_kg=500, total_sets=4)
    _add_session(session_factory, user_id, now - timedelta(days=1), duration_seconds=1200, total_volume_kg=200, total_sets=3)
    _add_session(session_factory, user_id, now - timedelta(days=10), duration_seconds=900)

    overview = client.get("/dashboard/overview", headers=headers).json()

    week = overview["week"]
    assert week["start"] == monday.isoformat()
    assert len(week["days"]) == 7
    in_week = [d for d in (today, today - timedelta(days=1)) if d >= monday]
    expected_seconds = (2400 if today in in_week else 0) + (1200 if today - timedelta(days=1) in in_week else 0)
    assert week["total_duration_seconds"] == expected_seconds
    today_totals = next(d for d in week["days"] if d["date"] == today.isoformat())
    assert today_totals == {
        "date": today.isoformat(), "sessions": 2, "duration_seconds": 2400, "volume_kg": 1500.0, "sets": 14
    }

    counts = {d["date"]: d["count"] for d in overview["heatmap"]["days"]}
    assert counts[today.isoformat()] == 2
    assert counts[(today - timedelta(days=1)).isoformat()] == 1
    assert len(counts) == 3

    assert overview["streak"] == {"current": 2, "best": 2, "trained_today": True}


def test_overview_uses_device_timezone(client, auth_headers, session_factory):
    headers = auth_headers()
    user_id = client.get("/me", headers=headers).json()["id"]
    # 01:00 UTC já é o dia seguinte em UTC, mas ainda é o dia anterior em Brasília (UTC-3).
    late_night = datetime.now(timezone.utc).replace(hour=1, minute=0, second=0, microsecond=0) - timedelta(days=3)
    _add_session(session_factory, user_id, late_night)

    utc = client.get("/dashboard/overview", headers=headers).json()["heatmap"]["days"]
    brt = client.get("/dashboard/overview", params={"tz_offset_minutes": -180}, headers=headers).json()["heatmap"]["days"]
    assert utc[0]["date"] == late_night.date().isoformat()
    assert brt[0]["date"] == (late_night.date() - timedelta(days=1)).isoformat()


@pytest.mark.parametrize(
    ("offsets", "expected"),
    [
        ((), (0, 0, False)),
        ((0, 1, 2), (3, 3, True)),
        ((1, 2, 3), (3, 3, False)),  # ainda não treinou hoje, mas a sequência de ontem vale
        ((2, 3), (0, 2, False)),  # ficou um dia inteiro sem treinar
        ((0, 2, 3, 4, 5), (1, 4, True)),
    ],
)
def test_compute_streak(offsets, expected):
    today = date(2026, 11, 8)
    streak = compute_streak({today - timedelta(days=o) for o in offsets}, today)
    assert (streak.current, streak.best, streak.trained_today) == expected
