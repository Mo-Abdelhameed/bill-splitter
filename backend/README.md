# Bill Splitter API

Stateless FastAPI service that the Flutter app calls to extract receipt items via Gemini 2.5 Flash.

## Run locally

```bash
python -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"
cp .env.example .env   # then fill in GEMINI_API_KEY, FIREBASE_PROJECT_ID, GOOGLE_APPLICATION_CREDENTIALS
uvicorn app.main:app --host 0.0.0.0 --port 8080 --reload
```

Smoke:

```bash
curl http://localhost:8080/v1/health
# → {"status":"ok"}
```

`POST /v1/extract` requires a valid Firebase Anonymous-Auth ID token. Easiest path is to drive it through the Flutter app.

## Tests

```bash
pytest -q
```

Suite covers: 401 without auth, 200 envelope shape, IMAGE_TOO_LARGE (>4 MB), INVALID_IMAGE (missing field / non-image MIME), zero-items happy path, no-CORS verification (no `Access-Control-*` headers, OPTIONS not handled).

## Docker

Build and run the container locally:

```bash
docker build -t bill-splitter-api .
docker run --rm -p 8080:8080 \
  -e GEMINI_API_KEY="$GEMINI_API_KEY" \
  -e FIREBASE_PROJECT_ID=bill-splitter-7e7f5 \
  -e GOOGLE_APPLICATION_CREDENTIALS=/app/firebase-admin.json \
  -v "$(pwd)/firebase-admin.json:/app/firebase-admin.json:ro" \
  bill-splitter-api
```

Smoke the container:

```bash
curl http://localhost:8080/v1/health
# → {"status":"ok"}
```

## Deploy (Cloud Run)

```bash
gcloud run deploy bill-splitter-api \
  --source . \
  --region me-central1 \
  --allow-unauthenticated \
  --set-env-vars FIREBASE_PROJECT_ID=bill-splitter-7e7f5 \
  --set-secrets GEMINI_API_KEY=gemini-api-key:latest
```

`--allow-unauthenticated` is the Cloud Run gate. The app-level gate — the only thing preventing arbitrary callers from burning Gemini quota — is the Firebase ID-token check inside FastAPI. Do not remove that.

## Project layout

```
backend/
├── app/
│   ├── main.py           # FastAPI app + exception handlers (NO CORSMiddleware)
│   ├── routes/
│   │   ├── extract.py    # POST /v1/extract — multipart, 4 MB cap, JPEG/PNG only, auth required
│   │   └── health.py     # GET /v1/health — unauthenticated liveness probe
│   ├── auth.py           # firebase-admin ID-token verification dep
│   ├── gemini.py         # google-genai async client
│   ├── extractor.py      # prompt + JSON parsing → ExtractResponse
│   ├── schemas.py        # pydantic models
│   └── errors.py         # error envelope helpers
├── tests/                # pytest, naming `FR-NNN: …`
├── Dockerfile            # python:3.12-slim + uvicorn
└── pyproject.toml
```
