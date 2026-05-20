"""Backend test for INVALID_IMAGE on POST /v1/extract.

Triggered when the multipart `image` field is missing, or the content-type
isn't an allowed image MIME (only image/jpeg and image/png pass).
"""
from __future__ import annotations


def test_fr_004_missing_image_field_returns_invalid_image(authed_client):
    """No image field in the multipart body -> INVALID_IMAGE envelope."""
    response = authed_client.post("/v1/extract", files={})
    assert response.status_code in (400, 422)
    body = response.json()
    assert body["error"]["code"] == "INVALID_IMAGE"


def test_fr_004_unsupported_mime_returns_invalid_image(authed_client):
    """A non-image MIME type -> INVALID_IMAGE envelope."""
    response = authed_client.post(
        "/v1/extract",
        files={"image": ("bill.pdf", b"%PDF-1.4 not really", "application/pdf")},
    )
    assert response.status_code == 400
    body = response.json()
    assert body["error"]["code"] == "INVALID_IMAGE"
