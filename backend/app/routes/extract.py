from __future__ import annotations

from fastapi import APIRouter, Depends, UploadFile, File

from .. import extractor
from ..auth import require_firebase_user
from ..errors import AppError, ErrorCode
from ..schemas import ExtractResponse

router = APIRouter()

_MAX_BYTES = 4 * 1024 * 1024  # 4 MB hard cap
_ALLOWED_MIMES = {"image/jpeg", "image/png"}


@router.post("/v1/extract", response_model=ExtractResponse)
async def extract(
    image: UploadFile = File(..., description="The bill image (jpeg or png, <= 4 MB)."),
    _user: dict = Depends(require_firebase_user),
) -> ExtractResponse:
    mime = (image.content_type or "").lower()
    if mime not in _ALLOWED_MIMES:
        raise AppError(
            400,
            ErrorCode.INVALID_IMAGE,
            "Image must be image/jpeg or image/png.",
        )

    data = await image.read()
    if len(data) > _MAX_BYTES:
        raise AppError(
            413,
            ErrorCode.IMAGE_TOO_LARGE,
            "Image exceeds the 4 MB limit.",
        )
    if not data:
        raise AppError(
            400,
            ErrorCode.INVALID_IMAGE,
            "Image is empty.",
        )

    return await extractor.extract_items(data, mime)
