from __future__ import annotations

import os

from .errors import AppError, ErrorCode

_MODEL = "gemini-2.5-flash"


def _get_client():
    api_key = os.environ.get("GEMINI_API_KEY")
    if not api_key:
        raise AppError(
            503,
            ErrorCode.EXTRACTION_UNAVAILABLE,
            "Extraction service is not configured.",
        )
    from google import genai

    return genai.Client(api_key=api_key)


async def call_gemini(image_bytes: bytes, mime: str, prompt: str) -> str:
    """Send the image + prompt to Gemini and return the raw text response."""
    client = _get_client()
    from google.genai import types

    try:
        response = await client.aio.models.generate_content(
            model=_MODEL,
            contents=[
                types.Part.from_bytes(data=image_bytes, mime_type=mime),
                prompt,
            ],
        )
    except Exception as exc:  # noqa: BLE001
        raise AppError(
            502,
            ErrorCode.EXTRACTION_FAILED,
            "Could not extract items from the image.",
        ) from exc

    text = getattr(response, "text", None)
    if not text:
        raise AppError(
            502,
            ErrorCode.EXTRACTION_FAILED,
            "Empty response from extraction service.",
        )
    return text
