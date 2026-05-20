"""Liveness probe — no auth required, used for Cloud Run health checks
and local-dev verification."""
from __future__ import annotations

from fastapi import APIRouter

router = APIRouter()


@router.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}
