"""Tests for app/auth/firebase.py — FR-002 (auth verification)."""
from __future__ import annotations

import pytest


def test_FR_002_missing_authorization_header_raises_unauthorized(mock_firebase_verify) -> None:
    """FR-002: missing Authorization header raises UnauthorizedError."""
    from app.auth.firebase import UnauthorizedError, verify_firebase_token

    with pytest.raises(UnauthorizedError):
        verify_firebase_token(None)


def test_FR_002_empty_authorization_header_raises_unauthorized(mock_firebase_verify) -> None:
    """FR-002: empty Authorization header raises UnauthorizedError."""
    from app.auth.firebase import UnauthorizedError, verify_firebase_token

    with pytest.raises(UnauthorizedError):
        verify_firebase_token("")


def test_FR_002_malformed_authorization_header_raises_unauthorized(mock_firebase_verify) -> None:
    """FR-002: header that does not start with `Bearer ` raises UnauthorizedError."""
    from app.auth.firebase import UnauthorizedError, verify_firebase_token

    with pytest.raises(UnauthorizedError):
        verify_firebase_token("Token abc")


def test_FR_002_invalid_token_raises_unauthorized(mock_firebase_verify) -> None:
    """FR-002: Firebase rejects the token; verify_firebase_token raises UnauthorizedError."""
    import firebase_admin.auth as fb_auth

    from app.auth.firebase import UnauthorizedError, verify_firebase_token

    mock_firebase_verify["exception"] = fb_auth.InvalidIdTokenError("bad signature")

    with pytest.raises(UnauthorizedError):
        verify_firebase_token("Bearer some.fake.token")


def test_FR_002_expired_token_raises_unauthorized(mock_firebase_verify) -> None:
    """FR-002: Firebase reports the token as expired; verify_firebase_token raises UnauthorizedError."""
    import firebase_admin.auth as fb_auth

    from app.auth.firebase import UnauthorizedError, verify_firebase_token

    mock_firebase_verify["exception"] = fb_auth.ExpiredIdTokenError("expired", cause=None)

    with pytest.raises(UnauthorizedError):
        verify_firebase_token("Bearer some.expired.token")


def test_FR_002_valid_token_returns_uid(mock_firebase_verify) -> None:
    """FR-002: a valid token returns the verified Firebase UID."""
    from app.auth.firebase import verify_firebase_token

    mock_firebase_verify["return_value"] = {"uid": "user-abc-123", "email": None}
    uid = verify_firebase_token("Bearer some.real.token")
    assert uid == "user-abc-123"
