"""Unit tests for app/services/gemini.py.

Covers FR-003 (success + quantity expansion + null tax/service) and FR-015
(typed error mapping). Mocks the google-generativeai SDK at the
GenerativeModel.generate_content boundary.
"""
from __future__ import annotations

import json
from types import SimpleNamespace
from typing import Any

import pytest


# ---- helpers ----------------------------------------------------------------


def _fake_response(text: str) -> SimpleNamespace:
    """Mimic the SDK's response object — exposes `.text`."""
    return SimpleNamespace(text=text)


def _patch_model(monkeypatch: pytest.MonkeyPatch, *, behavior: Any) -> None:
    """Replace `google.generativeai.GenerativeModel` so its
    `generate_content` invokes `behavior(prompt_parts) -> response`.
    """
    import google.generativeai as genai

    class FakeModel:
        def __init__(self, *args: Any, **kwargs: Any) -> None:
            pass

        def generate_content(self, parts: Any) -> Any:
            return behavior(parts)

    monkeypatch.setattr(genai, "GenerativeModel", FakeModel)
    # Some service implementations call configure(...) on import or per-call;
    # neutralise it so tests don't need a real API key.
    monkeypatch.setattr(genai, "configure", lambda **_: None)


# ---- FR-003 success ---------------------------------------------------------


def test_FR_003_success_returns_extraction_response(monkeypatch: pytest.MonkeyPatch) -> None:
    payload = json.dumps(
        {
            "items": [{"name": "burger", "price": 75.0}],
            "tax": 10.5,
            "service": 9.0,
        }
    )
    _patch_model(monkeypatch, behavior=lambda _: _fake_response(payload))

    from app.services.gemini import extract_items

    result = extract_items(b"\xff\xd8\xfffakebytes")
    assert len(result.items) == 1
    assert result.items[0].name == "burger"
    assert result.items[0].price == 75.0
    assert result.tax == 10.5
    assert result.service == 9.0


def test_FR_003_quantity_expansion_passes_through(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    """Quantity expansion is enforced by the system prompt sent to Gemini.
    The service trusts the SDK's response: if Gemini returns 3 separate
    items, the service returns 3 items."""
    payload = json.dumps(
        {
            "items": [
                {"name": "pasta", "price": 50.0},
                {"name": "pasta", "price": 50.0},
                {"name": "pasta", "price": 50.0},
            ],
            "tax": None,
            "service": None,
        }
    )
    _patch_model(monkeypatch, behavior=lambda _: _fake_response(payload))

    from app.services.gemini import extract_items

    result = extract_items(b"img")
    assert len(result.items) == 3
    assert all(it.name == "pasta" and it.price == 50.0 for it in result.items)


def test_FR_003_null_tax_and_service_preserved(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    payload = json.dumps(
        {"items": [{"name": "tea", "price": 20.0}], "tax": None, "service": None}
    )
    _patch_model(monkeypatch, behavior=lambda _: _fake_response(payload))

    from app.services.gemini import extract_items

    result = extract_items(b"img")
    assert result.tax is None
    assert result.service is None


# ---- FR-015 typed errors ----------------------------------------------------


def test_FR_015_sdk_network_failure_raises_NetworkError(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def boom(_: Any):
        raise ConnectionError("no route to host")

    _patch_model(monkeypatch, behavior=boom)

    from app.services.gemini import NetworkError, extract_items

    with pytest.raises(NetworkError):
        extract_items(b"img")


def test_FR_015_malformed_json_raises_ParseError(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    _patch_model(monkeypatch, behavior=lambda _: _fake_response("not json at all"))

    from app.services.gemini import ParseError, extract_items

    with pytest.raises(ParseError):
        extract_items(b"img")


def test_FR_015_missing_items_key_raises_SchemaError(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    payload = json.dumps({"tax": 0.0, "service": 0.0})  # no 'items'
    _patch_model(monkeypatch, behavior=lambda _: _fake_response(payload))

    from app.services.gemini import SchemaError, extract_items

    with pytest.raises(SchemaError):
        extract_items(b"img")


def test_FR_015_items_array_empty_raises_EmptyItemsError(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    payload = json.dumps({"items": [], "tax": None, "service": None})
    _patch_model(monkeypatch, behavior=lambda _: _fake_response(payload))

    from app.services.gemini import EmptyItemsError, extract_items

    with pytest.raises(EmptyItemsError):
        extract_items(b"img")
