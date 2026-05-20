"""Shared pytest fixtures for the backend test suite."""
from __future__ import annotations

from typing import Any
from unittest.mock import MagicMock

import pytest


@pytest.fixture
def mock_firebase_verify(monkeypatch: pytest.MonkeyPatch):
    """Mock `firebase_admin.auth.verify_id_token` and the SDK initializer.

    Tests can read/write this fixture's `return_value` (the decoded token dict)
    and `exception` (raised by the mock) to drive each scenario.
    """
    import firebase_admin
    import firebase_admin.auth

    state: dict[str, Any] = {"return_value": {"uid": "fake-uid"}, "exception": None}

    def fake_verify(token: str) -> dict[str, Any]:
        if state["exception"] is not None:
            raise state["exception"]
        return state["return_value"]

    monkeypatch.setattr(firebase_admin.auth, "verify_id_token", fake_verify)
    # Pretend the SDK is already initialized so verify_firebase_token's
    # idempotent-init logic skips the real initialize_app call.
    monkeypatch.setattr(firebase_admin, "_apps", {"[DEFAULT]": MagicMock()})
    return state
