from __future__ import annotations

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile

from app.models.extraction import ExtractedReceipt
from app.services.extractor import ReceiptExtractor, get_default_extractor


router = APIRouter()


def _extractor() -> ReceiptExtractor:
    return get_default_extractor()


@router.post("/extract", response_model=ExtractedReceipt)
async def extract_receipt(
    image: UploadFile = File(...),
    extractor: ReceiptExtractor = Depends(_extractor),
) -> ExtractedReceipt:
    if image.content_type is None or not image.content_type.startswith("image/"):
        raise HTTPException(status_code=400, detail="image/* upload required")
    data = await image.read()
    if not data:
        raise HTTPException(status_code=400, detail="empty image")
    return extractor.extract(data, image.content_type)
