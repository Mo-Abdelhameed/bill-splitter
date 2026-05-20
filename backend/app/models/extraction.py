"""Pydantic models for the /v1/extract endpoint.

Schema mirrors `specs/001-bill-split-flow/contracts/backend-api-v1.md`.
"""
from __future__ import annotations

from typing import Literal

from pydantic import BaseModel, Field


class ExtractedItem(BaseModel):
    name: str = Field(..., min_length=1)
    price: float = Field(..., ge=0)


class ExtractionResponse(BaseModel):
    items: list[ExtractedItem]
    tax: float | None = None
    service: float | None = None


ErrorCode = Literal[
    "bad_image",
    "unauthorized",
    "image_too_large",
    "network",
    "http",
    "parse",
    "schema",
    "empty",
]


class ErrorResponse(BaseModel):
    error: ErrorCode
    message: str
