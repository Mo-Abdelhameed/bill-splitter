from __future__ import annotations

import json
import re

from .errors import AppError, ErrorCode
from .gemini import call_gemini
from .schemas import ExtractResponse, ItemOut

PROMPT = """\
You are a careful receipt parser. Look at the attached restaurant bill image and
return a JSON object with this exact shape:

{
  "items": [
    {"name": "string", "quantity": <integer >= 1>, "unit_price": <number >= 0>}
  ],
  "tax_amount": <number or null>,
  "service_amount": <number or null>,
  "currency": "EGP"
}

Rules:
- One row per distinct menu item. "2x Coke" => one row with quantity=2.
- `unit_price` is the price PER UNIT, not the line total.
- If the receipt shows a tax line (VAT / ضريبة / 14%), put the EGP amount in `tax_amount`. Otherwise `null`.
- If the receipt shows a service line (service / خدمة / 12%), put the EGP amount in `service_amount`. Otherwise `null`.
- If you genuinely cannot make out any items, return `"items": []`. Do NOT invent items.
- Output ONLY the JSON object. No prose, no markdown fences.
"""


_FENCE_RE = re.compile(r"^```(?:json)?\s*|\s*```$", re.MULTILINE)


def _strip_fences(text: str) -> str:
    return _FENCE_RE.sub("", text).strip()


def _parse_payload(raw: str) -> dict:
    try:
        return json.loads(_strip_fences(raw))
    except json.JSONDecodeError as exc:
        raise AppError(
            502,
            ErrorCode.EXTRACTION_FAILED,
            "Extraction service returned an unparseable response.",
        ) from exc


async def extract_items(image_bytes: bytes, mime: str) -> ExtractResponse:
    raw = await call_gemini(image_bytes, mime, PROMPT)
    payload = _parse_payload(raw)

    items_raw = payload.get("items") or []
    if not isinstance(items_raw, list):
        raise AppError(
            502,
            ErrorCode.EXTRACTION_FAILED,
            "Extraction service returned a malformed items list.",
        )

    items: list[ItemOut] = []
    for entry in items_raw:
        try:
            items.append(ItemOut(**entry))
        except Exception as exc:  # noqa: BLE001 — pydantic ValidationError + others
            raise AppError(
                502,
                ErrorCode.EXTRACTION_FAILED,
                "Extraction service returned a malformed item.",
            ) from exc

    return ExtractResponse(
        items=items,
        tax_amount=payload.get("tax_amount"),
        service_amount=payload.get("service_amount"),
        currency=payload.get("currency", "EGP"),
    )
