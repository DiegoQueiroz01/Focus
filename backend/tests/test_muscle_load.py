import hashlib

SUPINO = "Barbell_Bench_Press_-_Medium_Grip"  # principal: peito; secundários: ombros e tríceps


def _treino_com_sessao(client, headers) -> tuple[list[int], int]:
    workout = client.post(
        "/workouts",
        json={
            "name": "Peito e costas",
            "exercises": [
                {"name": "Supino", "muscle_group": "chest", "catalog_id": SUPINO, "sets": 4, "reps": 10, "weight_kg": 40},
                {"name": "Remada do professor", "muscle_group": "back", "sets": 3, "reps": 12, "weight_kg": 30},
            ],
        },
        headers=headers,
    ).json()
    session = client.post(f"/workouts/{workout['id']}/sessions", headers=headers).json()
    return [e["id"] for e in workout["exercises"]], session["id"]


def test_finish_computes_muscle_load_per_session(client, auth_headers):
    headers = auth_headers()
    (supino, remada), session_id = _treino_com_sessao(client, headers)

    finished = client.post(
        f"/sessions/{session_id}/finish",
        json={
            "total_sets": 6,
            "completed_sets": [{"exercise_id": supino, "sets": 4}, {"exercise_id": remada, "sets": 2}],
        },
        headers=headers,
    ).json()

    # Catálogo: 1 por série nos principais e 0,5 nos secundários. Manual: grupo escolhido.
    assert finished["muscle_load"] == {
        "chest": 4.0,
        "lats": 2.0,
        "middle back": 2.0,
        "shoulders": 2.0,
        "triceps": 2.0,
    }

    week = client.get("/dashboard/overview", headers=headers).json()["week"]
    assert week["muscle_load"]["chest"] == 4.0


def test_muscle_load_is_empty_without_completed_sets(client, auth_headers):
    headers = auth_headers()
    _, session_id = _treino_com_sessao(client, headers)
    finished = client.post(f"/sessions/{session_id}/finish", json={}, headers=headers).json()
    assert finished["muscle_load"] == {}
    assert client.get("/dashboard/overview", headers=headers).json()["week"]["muscle_load"] == {}


def test_me_returns_gravatar_url(client, auth_headers):
    headers = auth_headers("diego@example.com")
    me = client.get("/me", headers=headers).json()
    digest = hashlib.sha256(b"diego@example.com").hexdigest()
    assert me["avatar_url"] == f"https://gravatar.com/avatar/{digest}?s=256&d=404"
