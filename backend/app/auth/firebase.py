"""Firebase Anonymous Auth ID-token verification.

The Flutter app obtains an anonymous-auth ID token from Firebase on launch
and attaches it to every backend request as ``Authorization: Bearer <token>``.
This module verifies that token before the request is allowed to reach
Gemini. See `specs/001-bill-split-flow/contracts/backend-api-v1.md`.
"""
from __future__ import annotations

import os
from typing import Final

import firebase_admin
from firebase_admin import auth as fb_auth
from firebase_admin import credentials


class UnauthorizedError(Exception):
    """Raised when an incoming request's Authorization header is invalid.

    The FastAPI dependency catches this and returns 401 with
    ``{"error": "unauthorized", "message": <detail>}``.
    """


_BEARER_PREFIX: Final[str] = "Bearer "


def _ensure_initialized() -> None:
    """Initialize firebase-admin exactly once, lazily.

    Skips if an app is already registered (the test fixture mocks
    ``firebase_admin._apps`` so the SDK reports as initialized without a
    real service account).
    """
    if firebase_admin._apps:  # type: ignore[attr-defined]
        return

    cred_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    if cred_path:
        firebase_admin.initialize_app(credentials.Certificate(cred_path))
    else:
        # On Cloud Run, Application Default Credentials work without a JSON file.
        firebase_admin.initialize_app()


def verify_firebase_token(authorization_header: str | None) -> str:
    """Verify a ``Bearer <id-token>`` Authorization header.

    Returns the verified Firebase UID. Raises [UnauthorizedError] for any
    missing/malformed header, expired token, bad signature, or any other
    rejection from ``firebase_admin.auth.verify_id_token``.
    """
    if not authorization_header or not authorization_header.startswith(_BEARER_PREFIX):
        raise UnauthorizedError("missing or malformed Authorization header")
    token = authorization_header[len(_BEARER_PREFIX):].strip()
    if not token:
        raise UnauthorizedError("missing or malformed Authorization header")

    _ensure_initialized()
    try:
        decoded = fb_auth.verify_id_token(token)
    except Exception as exc:  # noqa: BLE001 — firebase_admin raises several exception types
        raise UnauthorizedError(str(exc)) from exc

    uid = decoded.get("uid")
    if not uid:
        raise UnauthorizedError("token did not contain a uid")
    return uid
