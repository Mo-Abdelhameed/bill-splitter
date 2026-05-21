from __future__ import annotations

from pydantic import BaseModel, Field, NonNegativeFloat


class ReceiptItem(BaseModel):
    name: str
    price: NonNegativeFloat
    quantity: int = Field(default=1, ge=1)


class ReceiptCharges(BaseModel):
    tax: NonNegativeFloat | None = None
    service: NonNegativeFloat | None = None


class ExtractedReceipt(BaseModel):
    items: list[ReceiptItem] = Field(default_factory=list)
    charges: ReceiptCharges = Field(default_factory=ReceiptCharges)
    subtotal: NonNegativeFloat | None = None
    total: NonNegativeFloat | None = None
    currency: str | None = None
