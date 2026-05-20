from __future__ import annotations

from fastapi import HTTPException


class ErrorCode:
    INVALID_IMAGE = "INVALID_IMAGE"
    UNAUTHENTICATED = "UNAUTHENTICATED"
    IMAGE_TOO_LARGE = "IMAGE_TOO_LARGE"
    EXTRACTION_FAILED = "EXTRACTION_FAILED"
    EXTRACTION_UNAVAILABLE = "EXTRACTION_UNAVAILABLE"
    INTERNAL = "INTERNAL"


def envelope(code: str, message: str) -> dict:
    return {"error": {"code": code, "message": message}}


class AppError(HTTPException):
    def __init__(self, status_code: int, code: str, message: str) -> None:
        super().__init__(status_code=status_code, detail=envelope(code, message))
        self.code = code
        self.message = message
