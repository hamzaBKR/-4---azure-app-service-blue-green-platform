import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "app"))
from app import app

def test_home():
    client = app.test_client()
    response = client.get("/")
    assert response.status_code == 200
    assert b"Azure Service Status Dashboard" in response.data

def test_health(monkeypatch):
    monkeypatch.setenv("APP_VERSION", "1.0.0")
    monkeypatch.setenv("APP_ENVIRONMENT", "Test")
    client = app.test_client()
    response = client.get("/health")
    payload = response.get_json()
    assert response.status_code == 200
    assert payload["status"] == "healthy"
    assert payload["version"] == "1.0.0"
    assert payload["environment"] == "Test"
