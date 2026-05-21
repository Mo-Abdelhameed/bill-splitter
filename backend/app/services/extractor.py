"""Receipt extraction service.

Wraps the LLM call so it can be swapped for a stub in tests and during local
development without a Gemini API key. The public surface is `extract_receipt`,
which takes raw image bytes and a MIME type and returns an `ExtractedReceipt`.
"""

from __future__ import annotations

import json
import os
from typing import Protocol

from app.models.extraction import ExtractedReceipt, ReceiptCharges, ReceiptItem


EXTRACTION_PROMPT = """\
You are a receipt parser. Given the image of a restaurant receipt, return JSON
with this exact shape:

{
  "items": [{"name": str, "price": number, "quantity": int}, ...],
  "charges": {"tax": number|null, "service": number|null},
  "subtotal": number|null,
  "total": number|null,
  "currency": str|null
}

Rules:
- Classify each line as one of: item, tax, service, discount, other.
- ONLY food/drink/menu lines go into `items`. Each item's `price` is its
  line-extended price (price * quantity as shown on the receipt).
- Lines whose label matches tax (Tax, Sales Tax, VAT, TVA, GST, IVA, MwSt)
  go into `charges.tax`. Sum them if there are multiple.
- Lines whose label matches service or gratuity (Service, Service Charge,
  Gratuity, Tip, Servicio) go into `charges.service`. Sum them if multiple.
- Discounts and totals never appear in `items`.
- Numbers are decimal (e.g. 12.50). Do NOT include currency symbols.
- If a field is not present on the receipt, use null.
- Output ONLY the JSON object, no prose, no code fences.
"""


class ReceiptExtractor(Protocol):
    def extract(self, image_bytes: bytes, mime_type: str) -> ExtractedReceipt: ...


class GeminiExtractor:
    """Real extractor backed by Google Gemini (gemini-1.5-flash by default)."""

    def __init__(self, api_key: str, model_name: str = "gemini-1.5-flash") -> None:
        import google.generativeai as genai

        genai.configure(api_key=api_key)
        self._model = genai.GenerativeModel(model_name)

    def extract(self, image_bytes: bytes, mime_type: str) -> ExtractedReceipt:
        response = self._model.generate_content(
            [
                EXTRACTION_PROMPT,
                {"mime_type": mime_type, "data": image_bytes},
            ]
        )
        text = response.text.strip()
        if text.startswith("```"):
            text = text.strip("`")
            if text.lower().startswith("json"):
                text = text[4:]
            text = text.strip()
        payload = json.loads(text)
        return _parse_payload(payload)


class StubExtractor:
    """Fallback used when no API key is configured (local dev, tests)."""

    def extract(self, image_bytes: bytes, mime_type: str) -> ExtractedReceipt:
        return ExtractedReceipt(
            items=[
                ReceiptItem(name="Margherita Pizza", price=14.0),
                ReceiptItem(name="Caesar Salad", price=10.0),
                ReceiptItem(name="Sparkling Water", price=4.0),
                ReceiptItem(name="Tiramisu", price=8.0),
            ],
            charges=ReceiptCharges(tax=2.88, service=4.32),
            subtotal=36.0,
            total=43.2,
            currency="USD",
        )


def _parse_payload(payload: dict) -> ExtractedReceipt:
    raw_items = payload.get("items") or []
    items: list[ReceiptItem] = []
    for raw in raw_items:
        items.append(
            ReceiptItem(
                name=str(raw.get("name", "")).strip() or "Item",
                price=float(raw.get("price", 0) or 0),
                quantity=int(raw.get("quantity", 1) or 1),
            )
        )

    raw_charges = payload.get("charges") or {}
    charges = ReceiptCharges(
        tax=_opt_float(raw_charges.get("tax")),
        service=_opt_float(raw_charges.get("service")),
    )

    return ExtractedReceipt(
        items=items,
        charges=charges,
        subtotal=_opt_float(payload.get("subtotal")),
        total=_opt_float(payload.get("total")),
        currency=(payload.get("currency") or None),
    )


def _opt_float(value) -> float | None:
    if value is None:
        return None
    try:
        f = float(value)
    except (TypeError, ValueError):
        return None
    if f < 0:
        return None
    return f


def get_default_extractor() -> ReceiptExtractor:
    api_key = os.environ.get("GEMINI_API_KEY")
    if api_key:
        return GeminiExtractor(api_key=api_key)
    return StubExtractor()
