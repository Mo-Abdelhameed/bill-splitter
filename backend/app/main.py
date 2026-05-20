from __future__ import annotations

from dotenv import load_dotenv
from fastapi import FastAPI, Request

# Load backend/.env into os.environ before anything else imports auth/gemini.
load_dotenv()
from fastapi.exceptions import RequestValidationError
from fastapi.responses import JSONResponse

from .errors import AppError, ErrorCode, envelope
from .routes import extract, health

app = FastAPI(title="Bill Splitter API", version="0.1.0")

app.include_router(health.router)
app.include_router(extract.router)


@app.exception_handler(AppError)
async def _app_error_handler(_request: Request, exc: AppError) -> JSONResponse:
    return JSONResponse(status_code=exc.status_code, content=envelope(exc.code, exc.message))


@app.exception_handler(RequestValidationError)
async def _validation_handler(_request: Request, exc: RequestValidationError) -> JSONResponse:
    return JSONResponse(
        status_code=400,
        content=envelope(ErrorCode.INVALID_IMAGE, "Request validation failed."),
    )


@app.exception_handler(Exception)
async def _unhandled_handler(_request: Request, _exc: Exception) -> JSONResponse:
    return JSONResponse(
        status_code=500,
        content=envelope(ErrorCode.INTERNAL, "Internal server error."),
    )
