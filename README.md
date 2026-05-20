# Bill Split

A mobile app for splitting restaurant bills — designed for Egyptian restaurants but locale-overridable. Snap the receipt, drag names onto items, see who owes what.

## Tiers

- **`frontend/`** — Flutter app (iOS 13+, Android API 23+). Owns all bill state, math, and UI.
- **`backend/`** — Stateless FastAPI service. One job: accept a bill image and return structured items + tax/service via Gemini 2.5 Flash.

## Required external setup

The repo ships with placeholders; you supply the secrets.

### Firebase (Anonymous Auth)

1. Create / open the Firebase project (`bill-splitter`). Enable the **Anonymous** sign-in provider.
2. Add an iOS app (bundle id `com.billsplitter.billSplitter`) and an Android app (package `com.billsplitter.bill_splitter`).
3. Download configs into the standard Flutter locations:
   - `frontend/android/app/google-services.json`
   - `frontend/ios/Runner/GoogleService-Info.plist`
4. Generate a service account JSON for the backend (Firebase console → Project Settings → Service Accounts → Generate new private key) and place it at `backend/firebase-admin.json`.

All four files are gitignored.

### Gemini API key

Get an API key for Gemini Flash 2.5 and set `GEMINI_API_KEY` in `backend/.env` (copy from `backend/.env.example`). **Never** put this key in any Flutter file or `--dart-define`.

## Run locally

### Backend

```bash
cd backend
python -m venv .venv && source .venv/bin/activate
pip install -e ".[dev]"
cp .env.example .env   # fill in GEMINI_API_KEY, FIREBASE_PROJECT_ID, GOOGLE_APPLICATION_CREDENTIALS
uvicorn app.main:app --reload --port 8080
```

Smoke: `curl http://localhost:8080/v1/health` → `{"status":"ok"}`.

### Frontend

```bash
cd frontend
flutter pub get
flutter run --dart-define=API_BASE_URL=http://localhost:8080
```

## Test

```bash
cd backend && pytest -q
cd frontend && flutter test                  # unit + widget
cd frontend && flutter test integration_test # golden flow (needs a device/emulator)
```

## Deploy backend (Cloud Run)

```bash
cd backend
gcloud run deploy bill-splitter-api \
  --source . \
  --region me-central1 \
  --allow-unauthenticated \
  --set-env-vars FIREBASE_PROJECT_ID=bill-splitter \
  --set-secrets GEMINI_API_KEY=gemini-api-key:latest
```

`--allow-unauthenticated` is the Cloud Run gate; the app-level gate is the Firebase ID token check inside FastAPI.

## Spec-driven workflow

This project's spec lives in a SQLite DB served by `specs-mcp`, not in markdown. See `CLAUDE.md` for the rules. The four slash commands — `/speckit-specify`, `/speckit-plan`, `/speckit-tasks`, `/speckit-implement` — read and write through the DB.
