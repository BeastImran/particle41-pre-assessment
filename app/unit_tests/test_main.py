from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_index_success():
    response = client.get("/")
    assert response.status_code == 200
    data = response.json()
    assert "timestamp" in data
    assert "ip" in data
    assert isinstance(data["timestamp"], str)
    assert isinstance(data["ip"], str)


def test_index_with_x_forwarded_for():
    headers = {"x-forwarded-for": "1.2.3.4, 5.6.7.8"}
    response = client.get("/", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert data["ip"] == "1.2.3.4"


def test_internal_server_error(monkeypatch):
    # Simulate an exception in the endpoint
    def raise_exception(*args, **kwargs):
        raise Exception("Simulated error")

    monkeypatch.setattr("app.main.datetime", None)  # Break datetime.now
    response = client.get("/")
    assert response.status_code == 500
    assert response.json()["error"] == "Internal server error"
