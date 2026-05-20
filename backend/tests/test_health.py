"""Integration test for GET /v1/health — unauthenticated, returns 200 {ok}."""


def test_health_returns_ok_without_auth(client):
    response = client.get("/v1/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
