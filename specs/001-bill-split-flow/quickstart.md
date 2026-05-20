# Quickstart: Bill Split (frontend + backend, local dev)

This is the runnable-locally setup for the post-migration architecture. The Flutter app talks to the Python FastAPI backend; the backend holds the Gemini API key and verifies Firebase ID tokens.

## Prerequisites (one-time)

- **Flutter SDK** (stable channel), Xcode + CocoaPods (iOS), Android Studio + SDK (Android)
- **Python 3.12+** with `pip` and `venv`
- **Docker** (only required for the Cloud Run deploy step; not needed for local dev)
- **Gemini API key** from <https://aistudio.google.com/app/apikey>
- **A Firebase project** with Anonymous Auth enabled — see the next section.

## Step 1: Create the Firebase project (you, manually)

1. Go to <https://console.firebase.google.com> and click **Add project**. Name it (e.g.) `bill-split`. Accept the defaults for Google Analytics (disable is fine).
2. Inside the project: **Authentication → Get started → Sign-in method → Anonymous → Enable → Save.**
3. **Register the iOS app**: Project Settings (gear icon) → Add app → iOS. Bundle ID = `com.mohamedabdelhamid.billSplit` (matches the existing Xcode project). Download `GoogleService-Info.plist` and place it at `frontend/ios/Runner/GoogleService-Info.plist`.
4. **Register the Android app**: same screen → Add app → Android. Package name = `com.mohamedabdelhamid.bill_split`. Download `google-services.json` → `frontend/android/app/google-services.json`.
5. **Generate a backend service account**: Project Settings → Service Accounts → Generate new private key. Save the downloaded JSON as `backend/firebase-admin.json`. (This file is gitignored.)

## Step 2: Backend local dev

```bash
cd backend

# One-time setup
python3.12 -m venv .venv
source .venv/bin/activate
pip install -e .

# Environment
cp .env.example .env
# Edit backend/.env and set:
#   GEMINI_API_KEY=<your-key-from-step-prereq>
#   FIREBASE_PROJECT_ID=<your-firebase-project-id>
#   GOOGLE_APPLICATION_CREDENTIALS=./firebase-admin.json

# Run
uvicorn app.main:app --reload --port 8080
```

Backend is now listening on `http://localhost:8080`. Confirm with:

```bash
curl http://localhost:8080/v1/health
# Should return {"status": "ok"} (or similar; depends on the implementation)
```

## Step 3: Frontend local dev

```bash
cd frontend
flutter pub get

# Run on iOS simulator with the local backend URL injected at build time:
flutter run -d iphone \
  --dart-define=BACKEND_URL=http://localhost:8080/v1

# Or on Android emulator (note: the emulator can't reach 'localhost' on the host — use 10.0.2.2):
flutter run -d emulator \
  --dart-define=BACKEND_URL=http://10.0.2.2:8080/v1
```

On launch the app:
1. Initializes Firebase (using `GoogleService-Info.plist` / `google-services.json` from step 1).
2. Signs in anonymously, receives an ID token.
3. Attaches that token to every backend call via a `dio` interceptor.

## Step 4: Run the tests

### Frontend
```bash
cd frontend
flutter test          # full suite
flutter analyze       # zero errors required
```

### Backend
```bash
cd backend
source .venv/bin/activate
pytest                # full suite
```

## Step 5 (later): Deploy backend to Cloud Run

Defer until ready to ship to a real user. Outline:

```bash
cd backend
# Build the container image
docker build -t gcr.io/<your-gcp-project>/bill-split-backend:latest .

# Push to Google Container Registry
gcloud auth configure-docker
docker push gcr.io/<your-gcp-project>/bill-split-backend:latest

# Deploy to Cloud Run (free tier region of your choice, e.g. us-central1)
gcloud run deploy bill-split-backend \
  --image gcr.io/<your-gcp-project>/bill-split-backend:latest \
  --region us-central1 \
  --platform managed \
  --allow-unauthenticated \
  --set-env-vars GEMINI_API_KEY=<key>,FIREBASE_PROJECT_ID=<project-id> \
  --memory 512Mi \
  --max-instances 10
```

Note: `--allow-unauthenticated` here refers to Cloud Run's IAM-level auth, not the application-level Firebase auth. The Firebase token check is what actually gates real requests — `--allow-unauthenticated` simply means Cloud Run won't ALSO require GCP-IAM identity, which the Flutter app doesn't have.

Take the resulting `https://...` URL and use it as `BACKEND_URL` in your production Flutter build:

```bash
flutter build apk --release \
  --dart-define=BACKEND_URL=https://bill-split-backend-<hash>-uc.a.run.app/v1
```

## Common issues

- **"FirebaseException: no app named [DEFAULT]"** on iOS: missing or misplaced `GoogleService-Info.plist`. Re-do step 1.3.
- **Android can't reach `localhost`**: use `10.0.2.2` instead — that's the emulator's host loopback alias.
- **`401 unauthorized` from backend in dev**: the Firebase ID token expired (1-hour lifetime). The app should refresh automatically; if it doesn't, hot-restart the Flutter app.
- **`GEMINI_API_KEY` is empty on backend startup**: the `backend/.env` file isn't being loaded. Make sure you ran `cp .env.example .env` and edited the new file.
- **Hot reload on backend not picking up Python changes**: `uvicorn --reload` only watches `app/`. Restart manually for changes outside that directory.
