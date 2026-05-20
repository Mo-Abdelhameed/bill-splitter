FROM python:3.12-slim AS base

# Avoid pip cache + .pyc clutter inside the image.
ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1 \
    PIP_NO_CACHE_DIR=1 \
    PIP_DISABLE_PIP_VERSION_CHECK=1

WORKDIR /app

# Install OS deps needed by Pillow (libjpeg/libpng) and any C-extension wheels.
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        libjpeg62-turbo libpng16-16 \
    && rm -rf /var/lib/apt/lists/*

# Copy and install dependencies separately to leverage Docker layer caching.
COPY pyproject.toml ./
RUN pip install --upgrade pip setuptools wheel \
    && pip install .

# Now copy application code.
COPY app ./app

# Cloud Run injects PORT (default 8080). uvicorn must listen on 0.0.0.0:$PORT.
ENV PORT=8080
EXPOSE 8080
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port ${PORT}"]
