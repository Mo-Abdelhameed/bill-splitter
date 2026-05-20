"""POST /v1/extract — calls the Gemini service to extract items from a
receipt image.

The Firebase Auth check, multipart validation, and Gemini error mapping all
follow `specs/001-bill-split-flow/contracts/backend-api-v1.md`.
"""
from __future__ import annotations

from fastapi import APIRouter, Depends, Header, UploadFile, File, status
from fastapi.responses import JSONResponse

from app.auth.firebase import verify_firebase_token
from app.models.extraction import ErrorResponse, ExtractionResponse
from app.services import gemini as gemini_service

router = APIRouter()

_MAX_IMAGE_BYTES = 5 * 1024 * 1024  # 5 MB
_ALLOWED_CONTENT_TYPES = frozenset({"image/jpeg", "image/png"})


async def _require_firebase_uid(
    authorization: str | None = Header(default=None),
) -> str:
    # verify_firebase_token raises UnauthorizedError — caught by the global
    # handler in main.py, which returns the canonical {error, message} envelope.
    return verify_firebase_token(authorization)


def _error_response(status_code: int, code: str, message: str) -> JSONResponse:
    return JSONResponse(
        status_code=status_code,
        content=ErrorResponse(error=code, message=message).model_dump(),  # type: ignore[arg-type]
    )


@router.post("/extract")
async def extract(
    image: UploadFile = File(...),
    uid: str = Depends(_require_firebase_uid),
) -> JSONResponse:
    # Content-type validation (FR-002 → 415 bad_image).
    if image.content_type not in _ALLOWED_CONTENT_TYPES:
        return _error_response(
            status.HTTP_415_UNSUPPORTED_MEDIA_TYPE,
            "bad_image",
            f"content-type must be one of {sorted(_ALLOWED_CONTENT_TYPES)}",
        )

    image_bytes = await image.read()

    # Size validation (FR-002 → 413 image_too_large).
    if len(image_bytes) > _MAX_IMAGE_BYTES:
        return _error_response(
            413,
            "image_too_large",
            f"image must be ≤ {_MAX_IMAGE_BYTES} bytes (got {len(image_bytes)})",
        )

    # Call Gemini through the service layer. Each typed exception maps to a
    # specific HTTP status code + error code from contracts/backend-api-v1.md.
    try:
        result: ExtractionResponse = gemini_service.extract_items(image_bytes)
    except gemini_service.NetworkError as exc:
        return _error_response(status.HTTP_502_BAD_GATEWAY, "network", str(exc))
    except gemini_service.HttpError as exc:
        return _error_response(status.HTTP_502_BAD_GATEWAY, "http", str(exc))
    except gemini_service.ParseError as exc:
        return _error_response(
            status.HTTP_500_INTERNAL_SERVER_ERROR, "parse", str(exc)
        )
    except gemini_service.SchemaError as exc:
        return _error_response(
            status.HTTP_500_INTERNAL_SERVER_ERROR, "schema", str(exc)
        )
    except gemini_service.EmptyItemsError as exc:
        return _error_response(
            status.HTTP_500_INTERNAL_SERVER_ERROR, "empty", str(exc)
        )

    return JSONResponse(status_code=200, content=result.model_dump())
