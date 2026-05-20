"""Backend test for the 4 MB image size cap on POST /v1/extract.

The cap is enforced server-side so a malicious or buggy client cannot make us
forward arbitrarily large bytes to Gemini.
"""
from __future__ import annotations


def _oversized_jpeg_bytes(size_bytes: int) -> bytes:
    # Minimal JPEG magic header followed by padding — content doesn't matter,
    # only the byte length does for the size-cap check.
    header = b"\xff\xd8\xff\xe0"
    return header + b"\x00" * (size_bytes - len(header))


def test_fr_004_image_too_large_returns_413_envelope(authed_client):
    """An image > 4 MB returns IMAGE_TOO_LARGE in the error envelope."""
    five_mb = 5 * 1024 * 1024
    response = authed_client.post(
        "/v1/extract",
        files={"image": ("big.jpg", _oversized_jpeg_bytes(five_mb), "image/jpeg")},
    )
    assert response.status_code == 413
    body = response.json()
    assert body["error"]["code"] == "IMAGE_TOO_LARGE"
