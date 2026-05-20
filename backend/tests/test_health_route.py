"""Tests for the /v1/health endpoint."""
from __future__ import annotations

from fastapi.testclient import TestClient


def test_health_endpoint_returns_200_ok(mock_firebase_verify) -> None:
    """`GET /v1/health` returns 200 with status=ok. No auth required."""
    from app.main import app

    client = TestClient(app)
    response = client.get("/v1/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
