from fastapi.testclient import TestClient

from app.main import API_TOKEN, app

client = TestClient(app)


def test_healthz():
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json()["status"] == "ok"


def test_readyz():
    response = client.get("/readyz")
    assert response.status_code == 200
    assert response.json()["status"] == "ready"


def test_metrics_endpoint():
    response = client.get("/metrics")
    assert response.status_code == 200
    assert "http_requests_total" in response.text
    assert "http_request_duration_seconds" in response.text


def test_info_endpoint():
    response = client.get("/api/v1/info")
    assert response.status_code == 200
    data = response.json()
    assert "version" in data
    assert "hostname" in data
    assert "fault_mode" in data


def test_items_unauthorized():
    response = client.get("/api/v1/items")
    assert response.status_code == 401


def test_items_invalid_token():
    response = client.get(
        "/api/v1/items", headers={"Authorization": "Bearer invalid-token"}
    )
    assert response.status_code == 401


def test_items_valid_current_token():
    headers = {"Authorization": f"Bearer {API_TOKEN}"}
    response = client.get("/api/v1/items", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert data["auth_token_type"] == "current"
    assert "items" in data
    assert len(data["items"]) >= 1


def test_create_item_valid_token():
    headers = {"Authorization": f"Bearer {API_TOKEN}"}
    payload = {"name": "Test Database Replica", "category": "storage"}
    response = client.post("/api/v1/items", json=payload, headers=headers)
    assert response.status_code == 201
    data = response.json()
    assert data["created"]["name"] == "Test Database Replica"


def test_dual_token_rotation():
    import app.main as main_module
    main_module.API_TOKEN_PREVIOUS = "old-legacy-secret-token"

    # Previous token must be accepted during rotation
    response = client.get(
        "/api/v1/items",
        headers={"Authorization": "Bearer old-legacy-secret-token"},
    )
    assert response.status_code == 200
    assert response.json()["auth_token_type"] == "previous"

    # Reset
    main_module.API_TOKEN_PREVIOUS = ""


def test_fault_injection_endpoint():
    response = client.post("/api/v1/fault?mode=error500&error_rate=1.0")
    assert response.status_code == 200
    assert response.json()["fault_mode"] == "error500"

    # Reset to normal
    response = client.post("/api/v1/fault?mode=normal&error_rate=0.0")
    assert response.status_code == 200
