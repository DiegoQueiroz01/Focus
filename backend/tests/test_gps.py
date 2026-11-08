from app.gps import GpsActivityType, estimate_calories, route_preview


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
