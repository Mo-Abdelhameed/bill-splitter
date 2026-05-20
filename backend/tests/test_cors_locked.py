"""R-12: backend MUST NOT emit any Access-Control-* headers; OPTIONS preflights
are not handled."""
from __future__ import annotations


def test_options_extract_is_not_handled(client):
    response = client.options("/v1/extract")
    # FastAPI returns 405 (Method Not Allowed) when CORS middleware is absent,
    # which is exactly the behaviour we want.
    assert response.status_code == 405


def test_no_cors_headers_on_health(client):
    response = client.get(
        "/v1/health",
        headers={"Origin": "https://example.com"},
    )
    assert response.status_code == 200
    for header in response.headers:
        assert not header.lower().startswith("access-control-"), (
            f"unexpected CORS header: {header}"
        )


def test_no_cors_headers_on_extract_error(authed_client):
    # Trigger a 400 INVALID_IMAGE; verify no CORS header rides along.
    response = authed_client.post(
        "/v1/extract",
        files={"image": ("bill.pdf", b"%PDF", "application/pdf")},
        headers={"Origin": "https://example.com"},
    )
    assert response.status_code == 400
    for header in response.headers:
        assert not header.lower().startswith("access-control-"), (
            f"unexpected CORS header: {header}"
        )
