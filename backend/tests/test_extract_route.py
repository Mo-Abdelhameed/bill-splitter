"""Integration tests for POST /v1/extract.

Covers FR-002 (auth + multipart validation), FR-003 (success), FR-015 (error
mapping). The Gemini call is stubbed at the service layer via monkeypatch —
this keeps tests fast and decoupled from the SDK.
"""
from __future__ import annotations

import io

from fastapi.testclient import TestClient


# ---- helpers ----------------------------------------------------------------


def _client() -> TestClient:
    from app.main import app

    return TestClient(app)


def _jpeg(size_bytes: int = 64) -> tuple[str, io.BytesIO, str]:
    """A throwaway file part that satisfies the multipart contract."""
    return ("receipt.jpg", io.BytesIO(b"\xff\xd8\xff" + b"a" * size_bytes), "image/jpeg")


# ---- FR-002: auth + multipart validation -----------------------------------


def test_FR_002_missing_authorization_header_returns_401(mock_firebase_verify) -> None:
    response = _client().post(
        "/v1/extract",
        files={"image": _jpeg()},
    )
    assert response.status_code == 401, response.text
    body = response.json()
    assert body["error"] == "unauthorized"


def test_FR_002_malformed_token_returns_401(mock_firebase_verify) -> None:
    response = _client().post(
        "/v1/extract",
        files={"image": _jpeg()},
        headers={"Authorization": "Token nope"},
    )
    assert response.status_code == 401
    assert response.json()["error"] == "unauthorized"


def test_FR_002_missing_image_part_returns_400_bad_image(mock_firebase_verify) -> None:
    response = _client().post(
        "/v1/extract",
        headers={"Authorization": "Bearer ok"},
    )
    assert response.status_code == 400
    assert response.json()["error"] == "bad_image"


def test_FR_002_image_larger_than_5MB_returns_413_image_too_large(
    mock_firebase_verify,
) -> None:
    # 5 MB + 1 byte
    response = _client().post(
        "/v1/extract",
        files={"image": _jpeg(size_bytes=5 * 1024 * 1024 + 1)},
        headers={"Authorization": "Bearer ok"},
    )
    assert response.status_code == 413, response.text
    assert response.json()["error"] == "image_too_large"


def test_FR_002_wrong_content_type_returns_415_bad_image(mock_firebase_verify) -> None:
    response = _client().post(
        "/v1/extract",
        files={"image": ("receipt.txt", io.BytesIO(b"hello"), "text/plain")},
        headers={"Authorization": "Bearer ok"},
    )
    assert response.status_code == 415
    assert response.json()["error"] == "bad_image"


# ---- FR-003: success ---------------------------------------------------------


def test_FR_003_success_returns_parsed_items(monkeypatch, mock_firebase_verify) -> None:
    from app.models.extraction import ExtractedItem, ExtractionResponse
    from app.services import gemini as gemini_service

    captured: dict[str, bytes] = {}

    def fake_extract(image_bytes: bytes) -> ExtractionResponse:
        captured["bytes"] = image_bytes
        return ExtractionResponse(
            items=[
                ExtractedItem(name="pasta", price=50.0),
                ExtractedItem(name="pasta", price=50.0),
                ExtractedItem(name="salad", price=30.0),
            ],
            tax=14.0,
            service=12.0,
        )

    monkeypatch.setattr(gemini_service, "extract_items", fake_extract)

    response = _client().post(
        "/v1/extract",
        files={"image": _jpeg()},
        headers={"Authorization": "Bearer ok"},
    )
    assert response.status_code == 200, response.text
    body = response.json()
    assert len(body["items"]) == 3
    assert body["items"][0] == {"name": "pasta", "price": 50.0}
    assert body["tax"] == 14.0
    assert body["service"] == 12.0
    # The route forwarded the image bytes through to the service.
    assert captured["bytes"].startswith(b"\xff\xd8\xff")


# ---- FR-015: error mapping --------------------------------------------------


def test_FR_015_network_error_maps_to_502_network(monkeypatch, mock_firebase_verify) -> None:
    from app.services import gemini as gemini_service

    def boom(image_bytes: bytes):
        raise gemini_service.NetworkError("connection reset")

    monkeypatch.setattr(gemini_service, "extract_items", boom)

    response = _client().post(
        "/v1/extract",
        files={"image": _jpeg()},
        headers={"Authorization": "Bearer ok"},
    )
    assert response.status_code == 502
    assert response.json()["error"] == "network"


def test_FR_015_schema_error_maps_to_500_schema(monkeypatch, mock_firebase_verify) -> None:
    from app.services import gemini as gemini_service

    def boom(image_bytes: bytes):
        raise gemini_service.SchemaError("missing items key")

    monkeypatch.setattr(gemini_service, "extract_items", boom)

    response = _client().post(
        "/v1/extract",
        files={"image": _jpeg()},
        headers={"Authorization": "Bearer ok"},
    )
    assert response.status_code == 500
    assert response.json()["error"] == "schema"


def test_FR_015_empty_items_maps_to_500_empty(monkeypatch, mock_firebase_verify) -> None:
    from app.services import gemini as gemini_service

    def boom(image_bytes: bytes):
        raise gemini_service.EmptyItemsError("no items")

    monkeypatch.setattr(gemini_service, "extract_items", boom)

    response = _client().post(
        "/v1/extract",
        files={"image": _jpeg()},
        headers={"Authorization": "Bearer ok"},
    )
    assert response.status_code == 500
    assert response.json()["error"] == "empty"


def test_FR_015_parse_error_maps_to_500_parse(monkeypatch, mock_firebase_verify) -> None:
    from app.services import gemini as gemini_service

    def boom(image_bytes: bytes):
        raise gemini_service.ParseError("bad json")

    monkeypatch.setattr(gemini_service, "extract_items", boom)

    response = _client().post(
        "/v1/extract",
        files={"image": _jpeg()},
        headers={"Authorization": "Bearer ok"},
    )
    assert response.status_code == 500
    assert response.json()["error"] == "parse"
