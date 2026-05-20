"""Integration test for /v1/extract with the google-genai SDK call mocked.

Exercises the extract route → extractor → call_gemini pipeline end-to-end inside
the process; only the outbound HTTP to Gemini is stubbed.
"""
from __future__ import annotations

import io
import json

import pytest
from PIL import Image

from app import extractor as extractor_module
from app.gemini import call_gemini as _real_call_gemini  # noqa: F401 (ensures import works)


def _jpeg() -> bytes:
    buf = io.BytesIO()
    Image.new("RGB", (10, 10), color="white").save(buf, format="JPEG")
    return buf.getvalue()


@pytest.mark.asyncio
async def test_extract_happy_path_with_mocked_gemini(authed_client, monkeypatch):
    """Gemini returns parseable JSON → 200 with items + tax + service."""

    async def fake_call_gemini(image_bytes, mime, prompt):
        return json.dumps({
            "items": [
                {"name": "Koshary", "quantity": 2, "unit_price": 55},
                {"name": "Cola", "quantity": 1, "unit_price": 30},
            ],
            "tax_amount": 20,
            "service_amount": 17,
            "currency": "EGP",
        })

    monkeypatch.setattr(extractor_module, "call_gemini", fake_call_gemini)

    response = authed_client.post(
        "/v1/extract",
        files={"image": ("bill.jpg", _jpeg(), "image/jpeg")},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["currency"] == "EGP"
    assert body["tax_amount"] == 20
    assert body["service_amount"] == 17
    assert [it["name"] for it in body["items"]] == ["Koshary", "Cola"]


@pytest.mark.asyncio
async def test_extract_zero_items_returns_200_empty(authed_client, monkeypatch):
    """Gemini returns valid JSON with items=[] → 200 with empty items (not an error)."""

    async def fake_call_gemini(image_bytes, mime, prompt):
        return json.dumps({"items": [], "tax_amount": None, "service_amount": None, "currency": "EGP"})

    monkeypatch.setattr(extractor_module, "call_gemini", fake_call_gemini)

    response = authed_client.post(
        "/v1/extract",
        files={"image": ("bill.jpg", _jpeg(), "image/jpeg")},
    )
    assert response.status_code == 200
    body = response.json()
    assert body["items"] == []
    assert body["tax_amount"] is None
    assert body["service_amount"] is None


@pytest.mark.asyncio
async def test_extract_with_fenced_json_response(authed_client, monkeypatch):
    """Gemini wraps the JSON in ```json fences — extractor strips them and parses."""

    async def fake_call_gemini(image_bytes, mime, prompt):
        return (
            "```json\n"
            '{"items": [{"name": "Bread", "quantity": 1, "unit_price": 10}], '
            '"tax_amount": null, "service_amount": null, "currency": "EGP"}\n'
            "```"
        )

    monkeypatch.setattr(extractor_module, "call_gemini", fake_call_gemini)

    response = authed_client.post(
        "/v1/extract",
        files={"image": ("bill.jpg", _jpeg(), "image/jpeg")},
    )
    assert response.status_code == 200
    assert response.json()["items"][0]["name"] == "Bread"


@pytest.mark.asyncio
async def test_extract_with_unparseable_response_maps_to_extraction_failed(
    authed_client, monkeypatch
):
    """Gemini returns garbage → 502 EXTRACTION_FAILED envelope."""

    async def fake_call_gemini(image_bytes, mime, prompt):
        return "not even close to json"

    monkeypatch.setattr(extractor_module, "call_gemini", fake_call_gemini)

    response = authed_client.post(
        "/v1/extract",
        files={"image": ("bill.jpg", _jpeg(), "image/jpeg")},
    )
    assert response.status_code == 502
    assert response.json()["error"]["code"] == "EXTRACTION_FAILED"
