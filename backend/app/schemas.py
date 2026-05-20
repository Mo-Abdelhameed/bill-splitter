from __future__ import annotations

from pydantic import BaseModel, Field


class ItemOut(BaseModel):
    name: str
    quantity: int = Field(ge=1)
    unit_price: float = Field(ge=0)


class ExtractResponse(BaseModel):
    items: list[ItemOut]
    tax_amount: float | None = None
    service_amount: float | None = None
    currency: str = "EGP"


class ErrorBody(BaseModel):
    code: str
    message: str


class ErrorEnvelope(BaseModel):
    error: ErrorBody
