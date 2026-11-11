DAY = {
    "date": "2026-11-09",
    "steps": 8421,
    "distance_m": 6120.5,
    "active_calories": 410,
    "resting_hr": 58,
    "avg_hr": 74,
    "min_hr": 52,
    "max_hr": 141,
    "heart_rate_series": [[0, 60], [300, 55], [720, 90]],
    "sleep_minutes": 432,
    "sleep_deep_minutes": 80,
    "sleep_light_minutes": 250,
    "sleep_rem_minutes": 90,
    "sleep_awake_minutes": 12,
    "sleep_start": "2026-11-09T02:10:00Z",
    "sleep_end": "2026-11-09T09:34:00Z",
    "spo2_avg": 97.2,
    "spo2_min": 93,
}


def test_sync_creates_and_lists(client, auth_headers):
    headers = auth_headers()
    response = client.put("/health-data/days", json={"days": [DAY]}, headers=headers)
    assert response.status_code == 200
    assert response.json() == {"created": 1, "updated": 0}

    days = client.get(
        "/health-data/days", params={"start": "2026-11-01", "end": "2026-11-10"}, headers=headers
    ).json()
    assert len(days) == 1
    assert days[0]["steps"] == 8421
    assert days[0]["heart_rate_series"] == [[0, 60], [300, 55], [720, 90]]
    assert days[0]["sleep_minutes"] == 432


def test_resync_updates_without_erasing_missing_fields(client, auth_headers):
    headers = auth_headers()
    client.put("/health-data/days", json={"days": [DAY]}, headers=headers)

    # Novo envio do mesmo dia só com passos: o sono já salvo continua lá.
    response = client.put(
        "/health-data/days", json={"days": [{"date": "2026-11-09", "steps": 9000}]}, headers=headers
    )
    assert response.json() == {"created": 0, "updated": 1}

    day = client.get(
        "/health-data/days", params={"start": "2026-11-09", "end": "2026-11-09"}, headers=headers
    ).json()[0]
    assert day["steps"] == 9000
    assert day["sleep_minutes"] == 432


def test_days_are_isolated_per_user(client, auth_headers):
    client.put("/health-data/days", json={"days": [DAY]}, headers=auth_headers("a@example.com"))
    other = client.get(
        "/health-data/days",
        params={"start": "2026-11-01", "end": "2026-11-10"},
        headers=auth_headers("b@example.com"),
    )
    assert other.json() == []


def test_rejects_invalid_payloads(client, auth_headers):
    headers = auth_headers()
    bad_series = {**DAY, "heart_rate_series": [[2000, 60]]}
    assert client.put("/health-data/days", json={"days": [bad_series]}, headers=headers).status_code == 422

    swapped = {**DAY, "min_hr": 150, "max_hr": 100}
    assert client.put("/health-data/days", json={"days": [swapped]}, headers=headers).status_code == 422

    repeated = {"days": [{"date": "2026-11-09"}, {"date": "2026-11-09"}]}
    assert client.put("/health-data/days", json=repeated, headers=headers).status_code == 422

    assert client.put("/health-data/days", json={"days": []}, headers=headers).status_code == 422


def test_list_rejects_inverted_range(client, auth_headers):
    response = client.get(
        "/health-data/days", params={"start": "2026-11-10", "end": "2026-11-01"}, headers=auth_headers()
    )
    assert response.status_code == 422


def test_requires_auth(client):
    assert client.get("/health-data/days").status_code == 401
