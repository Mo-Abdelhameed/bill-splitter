"""Gemini 2.5 Flash extraction service.

Calls Gemini, parses its JSON response, and returns an `ExtractionResponse`.
Raises typed exceptions for every failure mode so the FastAPI route can map
each to the documented HTTP status (see `contracts/backend-api-v1.md`).
"""
from __future__ import annotations

import json
import logging
import time
from typing import Any

import google.generativeai as genai  # type: ignore[import-not-found]
from pydantic import ValidationError

from app.config import GEMINI_API_KEY
from app.models.extraction import ExtractedItem, ExtractionResponse

logger = logging.getLogger(__name__)


# ---- Typed errors -----------------------------------------------------------


class GeminiServiceError(Exception):
    """Base for all extraction-service failures."""


class NetworkError(GeminiServiceError):
    """Transport-level failure (connection refused, DNS, TLS, timeout)."""


class HttpError(GeminiServiceError):
    """Gemini returned a non-2xx HTTP response."""


class ParseError(GeminiServiceError):
    """Response body was not parseable as JSON."""


class SchemaError(GeminiServiceError):
    """JSON parsed but did not match the expected schema."""


class EmptyItemsError(GeminiServiceError):
    """Schema valid but the `items` array was empty."""


# ---- Prompt -----------------------------------------------------------------

# Same instruction the throwaway tmp/run_extract.py used; keep them in sync.
# Key contract points (FR-003):
#   - One element per single unit of purchase (quantity > 1 → expand).
#   - price per single unit, plain number.
#   - tax / service: numeric if printed on the receipt, null otherwise.
_SYSTEM_PROMPT = (
    "You are an OCR + structuring engine for restaurant receipts. "
    "Read the receipt image and return ONLY JSON matching this schema:\n"
    '  { "items": [ { "name": string, "price": number }, ... ], '
    '"tax": number|null, "service": number|null }\n'
    "Rules:\n"
    "1. Output one element in items[] per SINGLE UNIT of purchase. If a line "
    'reads "2x Pasta 100", emit TWO entries each priced 50.0.\n'
    "2. price is the per-unit price as a plain number (no currency symbol, "
    "no thousand separators).\n"
    "3. tax is the explicit tax amount printed on the receipt (e.g. VAT line). "
    "If no tax line is shown, return null. Do NOT compute it.\n"
    "4. service is the explicit service-charge amount printed on the receipt. "
    "If absent, return null. Do NOT compute it.\n"
    "5. Do not include subtotals, totals, discounts, or non-item rows in items[].\n"
    "6. Use the item name as printed (transliterate Arabic to Latin if the "
    "receipt is bilingual; pick the English line if both are present).\n"
    "Respond with JSON only — no prose, no markdown fences."
)

_MODEL_NAME = "gemini-2.5-flash"


# ---- Public entry point ----------------------------------------------------


def extract_items(image_bytes: bytes) -> ExtractionResponse:
    """Send `image_bytes` to Gemini and return the parsed response.

    Raises:
        NetworkError: transport-level failure (connection / DNS / TLS / timeout).
        HttpError:    Gemini returned a non-2xx HTTP response.
        ParseError:   response body wasn't JSON-decodable.
        SchemaError:  decoded JSON didn't match the schema.
        EmptyItemsError: schema valid but items[] was empty.
    """
    if GEMINI_API_KEY:
        # Idempotent — safe to call on every request.
        genai.configure(api_key=GEMINI_API_KEY)

    model = genai.GenerativeModel(
        _MODEL_NAME,
        system_instruction=_SYSTEM_PROMPT,
        generation_config={"response_mime_type": "application/json"},
    )

    start = time.monotonic()
    try:
        response = model.generate_content(
            [
                {"mime_type": "image/jpeg", "data": image_bytes},
                "Extract the receipt now.",
            ]
        )
    except ConnectionError as exc:
        raise NetworkError(str(exc)) from exc
    except TimeoutError as exc:
        raise NetworkError(f"timeout: {exc}") from exc
    except Exception as exc:
        # Catch-all: google-generativeai surfaces several distinct exception
        # types depending on whether the failure is transport-level or
        # server-side. Without a deeper SDK match here we conservatively map
        # them to HttpError; tests for both shapes patch the model directly,
        # so the SDK-specific paths only matter in production.
        msg = str(exc).lower()
        if any(s in msg for s in ("connection", "dns", "timeout", "tls", "ssl")):
            raise NetworkError(str(exc)) from exc
        raise HttpError(str(exc)) from exc

    latency_ms = int((time.monotonic() - start) * 1000)
    logger.info("gemini.latency_ms=%d", latency_ms)

    text = getattr(response, "text", None)
    if not text:
        raise ParseError("empty response body from Gemini")

    try:
        parsed: Any = json.loads(text)
    except json.JSONDecodeError as exc:
        raise ParseError(f"invalid JSON: {exc.msg}") from exc

    if not isinstance(parsed, dict) or "items" not in parsed:
        raise SchemaError("missing 'items' key")
    items_raw = parsed.get("items")
    if not isinstance(items_raw, list):
        raise SchemaError("'items' must be a list")
    if len(items_raw) == 0:
        raise EmptyItemsError("Gemini returned 0 items")

    try:
        items = [ExtractedItem.model_validate(it) for it in items_raw]
        response_obj = ExtractionResponse(
            items=items,
            tax=parsed.get("tax"),
            service=parsed.get("service"),
        )
    except ValidationError as exc:
        raise SchemaError(str(exc)) from exc

    return response_obj
