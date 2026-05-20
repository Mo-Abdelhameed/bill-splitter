"""Shared pytest fixtures for the backend test suite.

The Firebase token verification dependency is patched so tests don't need a real
Firebase project. The Gemini SDK is patched per-test where needed.
"""
from __future__ import annotations

import pytest
from fastapi.testclient import TestClient

from app.auth import require_firebase_user
from app.main import app


@pytest.fixture
def auth_override():
    """Yields a context that overrides require_firebase_user to accept any caller."""

    def _fake_user():
        return {"uid": "test-user", "firebase": {"sign_in_provider": "anonymous"}}

    app.dependency_overrides[require_firebase_user] = _fake_user
    yield
    app.dependency_overrides.pop(require_firebase_user, None)


@pytest.fixture
def client():
    return TestClient(app)


@pytest.fixture
def authed_client(auth_override, client):
    return client
