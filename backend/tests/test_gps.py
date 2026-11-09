from app.gps import MAX_SETS_PER_ACTIVITY, GpsActivityType, estimate_calories, muscle_load, route_preview


def _payload(**fields) -> dict:
    route = [[-12.97 + i * 0.0001, -38.5, 10.0 + i, i * 3.0] for i in range(200)]
    return {
        "activity_type": "run",
        "started_at": "2026-11-08T06:00:00-03:00",
        "finished_at": "2026-11-08T06:31:00-03:00",
        "elapsed_seconds": 1860,
        "moving_seconds": 1800,
        "distance_m": 5000.0,
        "elevation_gain_m": 42.0,
        "elevation_loss_m": 40.0,
        "max_speed_mps": 4.2,
        "comment": "  Ritmo bom  ",
        "route": route,
        "splits": [360, 355, 362, 350, 348],
        **fields,
    }


def test_gps_activity_crud(client, auth_headers):
    headers = auth_headers()
    created = client.post("/gps-activities", json=_payload(), headers=headers)
    assert created.status_code == 201
    body = created.json()
    assert body["calories"] == estimate_calories(GpsActivityType.RUN, 1800)
    assert body["comment"] == "Ritmo bom"
    assert len(body["route"]) == 200 and body["splits"][0] == 360

    listed = client.get("/gps-activities", headers=headers).json()
    assert len(listed) == 1 and "route" not in listed[0]
    assert len(listed[0]["route_preview"]) == 80

    activity_id = body["id"]
    updated = client.put(
        f"/gps-activities/{activity_id}/comment", json={"comment": "Novo"}, headers=headers
    )
    assert updated.json()["comment"] == "Novo"

    other = auth_headers("outra@example.com")
    assert client.get(f"/gps-activities/{activity_id}", headers=other).status_code == 404

    assert client.delete(f"/gps-activities/{activity_id}", headers=headers).status_code == 204
    assert client.get("/gps-activities", headers=headers).json() == []


def test_gps_activity_validation(client, auth_headers):
    headers = auth_headers()
    post = lambda **f: client.post("/gps-activities", json=_payload(**f), headers=headers)  # noqa: E731
    assert post(activity_type="swim").status_code == 422
    assert post(moving_seconds=9999).status_code == 422
    assert post(route=[[95, 0, None, 0]]).status_code == 422


def test_route_preview_keeps_ends():
    route = [[float(i), 0.0, None, float(i)] for i in range(1000)]
    preview = route_preview(route, max_points=10)
    assert preview[0] == [0.0, 0.0] and preview[-1] == [999.0, 0.0] and len(preview) == 10


def test_muscle_load_by_activity():
    # 30 min de corrida = 6 séries nas pernas; abdômen como secundário.
    run = muscle_load(GpsActivityType.RUN, 1800)
    assert run["quadriceps"] == 6 and run["calves"] == 6 and run["abdominals"] == 3
    # Caminhada é mais leve: 30 min = 3 séries.
    assert muscle_load(GpsActivityType.WALK, 1800)["quadriceps"] == 3
    # Limite por atividade e casos vazios.
    assert muscle_load(GpsActivityType.RIDE, 6 * 3600)["quadriceps"] == MAX_SETS_PER_ACTIVITY
    assert muscle_load(GpsActivityType.RUN, 0) == {}
    assert muscle_load("swim", 1800) == {}


def test_gps_list_filters_by_date_and_exposes_muscle_load(client, auth_headers):
    headers = auth_headers()
    client.post("/gps-activities", json=_payload(), headers=headers)
    client.post(
        "/gps-activities",
        json=_payload(started_at="2026-11-07T06:00:00-03:00", finished_at="2026-11-07T06:31:00-03:00"),
        headers=headers,
    )
    day = client.get(
        "/gps-activities",
        params={"start": "2026-11-08T03:00:00Z", "end": "2026-11-09T03:00:00Z"},
        headers=headers,
    ).json()
    assert len(day) == 1 and day[0]["started_at"].startswith("2026-11-08")
    assert day[0]["muscle_load"]["quadriceps"] == 6


def test_overview_counts_gps_activities(client, auth_headers, session_factory):
    from datetime import datetime, timedelta, timezone

    from app.models import WorkoutSession

    headers = auth_headers()
    user_id = client.get("/me", headers=headers).json()["id"]
    now = datetime.now(timezone.utc).replace(hour=15, minute=0, second=0, microsecond=0)
    today = now.date()
    yesterday = now - timedelta(days=1)

    # Ontem: só um treino. Hoje: só uma corrida de 30 min e 5 km.
    with session_factory() as db:
        db.add(WorkoutSession(
            user_id=user_id, workout_name="Peito", workout_type="musculacao",
            started_at=yesterday, finished_at=yesterday + timedelta(minutes=40),
            duration_seconds=2400, total_volume_kg=1000, total_sets=10,
            muscle_load={"chest": 10.0},
        ))
        db.commit()
    started = now.isoformat()
    finished = (now + timedelta(minutes=31)).isoformat()
    client.post("/gps-activities", json=_payload(started_at=started, finished_at=finished), headers=headers)

    overview = client.get("/dashboard/overview", headers=headers).json()

    assert overview["streak"] == {"current": 2, "best": 2, "trained_today": True}
    counts = {d["date"]: d["count"] for d in overview["heatmap"]["days"]}
    assert counts[today.isoformat()] == 1

    week = overview["week"]
    today_totals = next(d for d in week["days"] if d["date"] == today.isoformat())
    assert today_totals["gps_activities"] == 1 and today_totals["sessions"] == 0
    assert today_totals["duration_seconds"] == 1800 and today_totals["distance_m"] == 5000.0
    assert week["total_gps_activities"] == 1 and week["total_distance_m"] == 5000.0
    assert week["muscle_load"]["quadriceps"] == 6
