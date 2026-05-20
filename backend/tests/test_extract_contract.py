"""Contract tests for POST /v1/extract.

Covers FR-004 (the app submits the image and receives items + tax/service via
the documented response envelope) and the 401 gate from R-6.
"""
from __future__ import annotations

import io

import pytest
from PIL import Image

from app import extractor
from app.schemas import ExtractResponse, ItemOut


def _jpeg_bytes() -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (10, 10), color="white").save(buf, format="JPEG")
    return buf.getvalue()


def test_fr_004_unauthenticated_returns_401(client):
    """FR-004: /v1/extract without an Authorization header returns 401 envelope."""
    response = client.post(
        "/v1/extract",
        files={"image": ("bill.jpg", _jpeg_bytes(), "image/jpeg")},
    )
    assert response.status_code == 401
    body = response.json()
    assert body == {
        "error": {"code": "UNAUTHENTICATED", "message": body["error"]["message"]}
    }


def test_fr_004_returns_extract_envelope(authed_client, monkeypatch):
    """FR-004: a valid image returns items + optional tax/service in EGP envelope."""

    async def fake_extract(image_bytes: bytes, mime: str) -> ExtractResponse:
        return ExtractResponse(
            items=[
                ItemOut(name="Koshary", quantity=2, unit_price=55),
                ItemOut(name="Cola", quantity=1, unit_price=30),
            ],
            tax_amount=20,
            service_amount=17,
            currency="EGP",
        )

    monkeypatch.setattr(extractor, "extract_items", fake_extract)

    response = authed_client.post(
        "/v1/extract",
        files={"image": ("bill.jpg", _jpeg_bytes(), "image/jpeg")},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["currency"] == "EGP"
    assert body["tax_amount"] == 20
    assert body["service_amount"] == 17
    assert len(body["items"]) == 2
    assert body["items"][0] == {"name": "Koshary", "quantity": 2, "unit_price": 55.0}


def test_fr_004_zero_items_returns_200_with_empty_list(authed_client, monkeypatch):
    """FR-004 + plan rule: zero items is a successful 200, not an error."""

    async def fake_extract(image_bytes: bytes, mime: str) -> ExtractResponse:
        return ExtractResponse(items=[], tax_amount=None, service_amount=None, currency="EGP")

    monkeypatch.setattr(extractor, "extract_items", fake_extract)

    response = authed_client.post(
        "/v1/extract",
        files={"image": ("bill.jpg", _jpeg_bytes(), "image/jpeg")},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["items"] == []
    assert body["tax_amount"] is None
    assert body["service_amount"] is None
