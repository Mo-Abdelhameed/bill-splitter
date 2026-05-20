"""Backend configuration loaded from environment variables.

Read once at module import. Cloud Run injects env vars; local dev uses
``backend/.env`` (loaded by ``python-dotenv`` automatically when uvicorn
is started with ``--env-file`` or when the developer pre-exports them).
"""
from __future__ import annotations

import os
from typing import Final


def _load_local_env() -> None:
    """Best-effort load of a `.env` next to this module's package.

    On Cloud Run the env vars come from the platform; this is purely a
    developer-experience convenience for local runs.
    """
    try:
        from dotenv import load_dotenv
    except ImportError:
        return
    load_dotenv()


_load_local_env()


GEMINI_API_KEY: Final[str] = os.environ.get("GEMINI_API_KEY", "")
FIREBASE_PROJECT_ID: Final[str] = os.environ.get("FIREBASE_PROJECT_ID", "")
GOOGLE_APPLICATION_CREDENTIALS: Final[str] = os.environ.get(
    "GOOGLE_APPLICATION_CREDENTIALS", ""
)
