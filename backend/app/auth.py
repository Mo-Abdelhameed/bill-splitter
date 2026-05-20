from __future__ import annotations

import os
from typing import Any

from fastapi import Header

from .errors import AppError, ErrorCode

_firebase_initialized = False


def _ensure_firebase() -> None:
    global _firebase_initialized
    if _firebase_initialized:
        return
    import firebase_admin
    from firebase_admin import credentials

    if firebase_admin._apps:
        _firebase_initialized = True
        return

    cred_path = os.environ.get("GOOGLE_APPLICATION_CREDENTIALS")
    project_id = os.environ.get("FIREBASE_PROJECT_ID")
    options = {"projectId": project_id} if project_id else None
    cred = credentials.Certificate(cred_path) if cred_path else credentials.ApplicationDefault()
    firebase_admin.initialize_app(cred, options)
    _firebase_initialized = True


def verify_id_token(token: str) -> dict[str, Any]:
    _ensure_firebase()
    from firebase_admin import auth as fb_auth

    try:
        return fb_auth.verify_id_token(token)
    except Exception as exc:  # noqa: BLE001 — firebase-admin raises many subtypes
        raise AppError(401, ErrorCode.UNAUTHENTICATED, "Invalid or expired ID token.") from exc


async def require_firebase_user(
    authorization: str | None = Header(default=None),
) -> dict[str, Any]:
    if not authorization or not authorization.lower().startswith("bearer "):
        raise AppError(401, ErrorCode.UNAUTHENTICATED, "Missing Authorization bearer token.")
    token = authorization.split(" ", 1)[1].strip()
    if not token:
        raise AppError(401, ErrorCode.UNAUTHENTICATED, "Missing Authorization bearer token.")
    return verify_id_token(token)
