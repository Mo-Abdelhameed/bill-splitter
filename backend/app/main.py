"""FastAPI app entrypoint. Mounted at /v1 — every endpoint lives under
that prefix per the API contract."""
from __future__ import annotations

from fastapi import FastAPI, Request, status
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from app.auth.firebase import UnauthorizedError
from app.models.extraction import ErrorResponse
from app.routes import extract as extract_route
from app.routes import health as health_route

app = FastAPI(
    title="Bill Split Backend",
    version="0.1.0",
    description="Stateless proxy from the Flutter app to Gemini 2.5 Flash.",
)

app.include_router(health_route.router, prefix="/v1")
app.include_router(extract_route.router, prefix="/v1")


@app.exception_handler(UnauthorizedError)
async def _unauthorized_handler(request: Request, exc: UnauthorizedError) -> JSONResponse:
    return JSONResponse(
        status_code=status.HTTP_401_UNAUTHORIZED,
        content=ErrorResponse(error="unauthorized", message=str(exc)).model_dump(),
    )


@app.exception_handler(RequestValidationError)
async def _bad_image_handler(request: Request, exc: RequestValidationError) -> JSONResponse:
    # Multipart/file validation failures get mapped to error="bad_image".
    return JSONResponse(
        status_code=status.HTTP_400_BAD_REQUEST,
        content=ErrorResponse(error="bad_image", message=str(exc)).model_dump(),
    )
