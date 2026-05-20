# Bill Split

A mobile app for splitting restaurant bills — designed for Egyptian restaurants but locale-overridable. Snap the receipt, drag names onto items, see who owes what.

The app is two tiers:

- **Flutter frontend** (`frontend/`) — iOS + Android. The five-screen flow is People → Capture → Extraction → Assignment → Totals.
- **Python backend** (`backend/`) — FastAPI service that proxies receipt images to Gemini 2.5 Flash for OCR + structuring. Holds the Gemini API key so it never ships inside the app.

Every backend request is authenticated with a Firebase Anonymous Auth ID token.

## Why two tiers?

The Gemini API key cannot ship in a mobile build (anyone with the IPA / APK could lift it and burn through the quota). The backend holds the key, the app holds nothing but a Firebase ID token. The backend is stateless — no database, no per-user storage — so it scales-to-zero comfortably on Cloud Run's free tier.

## The split math

- **Items** — each entry is a single unit. If a receipt prints "Pasta × 3", Gemini emits three rows so each unit can be assigned independently.
- **Assignment** — drag a name chip onto an item, or tap an item to open a per-person checkbox modal. Long-press an assignee's chip to give them a per-item weight (default 1; weight 2 means double-share).
- **Tax + service** — on the Extraction screen each charge has a checkbox to mark it present, plus a segmented control: *Included in items* (already baked into prices) vs *Added on top* (added to the subtotal). The Totals screen does the right math for both.
- **Rounding residual** — sub-currency-unit drift (e.g. 0.01 EGP when 100 splits 3 ways) is surfaced on a dedicated "Rounding" line, never silently absorbed.

## Tech stack

| Tier | Stack |
|---|---|
| Frontend | Flutter (stable), Dart 3.x, `go_router`, `dio`, `image_picker`, `permission_handler`, `firebase_core`, `firebase_auth`, `image`, `uuid` |
| Backend | Python 3.12, FastAPI, `uvicorn`, `google-generativeai`, `firebase-admin`, `pydantic`, `Pillow` |
| Testing | `flutter_test`, `pytest` |
| Auth | Firebase Anonymous Auth (token verified server-side via `firebase-admin`) |
| OCR / structuring | Gemini 2.5 Flash |
| Deploy target | Cloud Run free tier (backend); TestFlight / App Store (frontend) |

## Quick start (local dev)

You need: Flutter SDK (stable channel), Python 3.12, a Firebase project with Anonymous Auth enabled, and a Gemini API key.

### 1. Backend

```bash
cd backend
python3 -m venv .venv
.venv/bin/pip install -e ".[dev]"
cp .env.example .env       # then fill in GEMINI_API_KEY, FIREBASE_PROJECT_ID, GOOGLE_APPLICATION_CREDENTIALS
# Put the Firebase Admin service-account JSON at the path GOOGLE_APPLICATION_CREDENTIALS points to
make backend-run           # uvicorn on http://0.0.0.0:9090
```

`make backend-run` binds to all interfaces so a real iPhone on the same Wi-Fi can reach the Mac. Local-only is fine too; the auth gate is identical.

Smoke check:
```bash
curl -s http://localhost:9090/v1/health   # → {"status":"ok"}
```

### 2. Frontend

```bash
cd frontend
flutter pub get
# Optional, after editing ios/Podfile or upgrading a native plugin:
#   make frontend-ios-rebuild
flutter run -d <device-id> --dart-define=BACKEND_URL=http://<your-mac-lan-ip>:9090/v1
```

If you're on the iOS Simulator instead of a real device, `http://localhost:9090/v1` is enough — the default in `BackendClient.defaultLocalBaseUrl`. On a physical iPhone you need the Mac's LAN IP (`ipconfig getifaddr en0`). On the Android emulator, use `10.0.2.2` instead of `localhost`.

## Project layout

```
.
├── backend/
│   ├── app/
│   │   ├── auth/firebase.py          # Verifies Firebase Anonymous Auth ID tokens
│   │   ├── routes/{health,extract}.py
│   │   ├── services/gemini.py        # Gemini 2.5 Flash client, typed errors
│   │   └── models/extraction.py      # Pydantic wire types
│   ├── tests/                        # pytest suite
│   ├── pyproject.toml
│   └── Dockerfile
├── frontend/
│   ├── lib/
│   │   ├── screens/                  # People, Capture, Extraction, Assignment, Totals
│   │   ├── widgets/                  # FlowStepper, BackChevronBar, BottomActionBar
│   │   ├── services/                 # BackendClient, ExtractionClient, ImageAcquirer, ImageResizer
│   │   ├── state/                    # BillState, BillItem
│   │   ├── theme.dart                # Design tokens (light + dark) as a ThemeExtension
│   │   └── router.dart
│   ├── test/                         # Mirrors lib/; tests named `FR-NNN: ...`
│   ├── assets/icon/                  # Master 1024×1024 PNG + SVG for the launcher icon
│   ├── ios/  android/                # Platform projects
│   └── pubspec.yaml
├── specs/
│   ├── 001-bill-split-flow/          # Active feature: spec, plan, tasks, contracts, UI mocks
│   └── ...
├── .specify/                         # GitHub spec-kit config + skill templates
├── CLAUDE.md                         # Operational guide for Claude Code
├── Makefile                          # Top-level convenience targets
└── README.md
```

## Make targets

| Target | What it does |
|---|---|
| `make test` | `flutter test` + `pytest` |
| `make analyze` | `flutter analyze` |
| `make frontend-run-ios` | `flutter run -d iphone` (booted Simulator) |
| `make frontend-run-android` | `flutter run -d emulator` |
| `make frontend-ios-rebuild` | `flutter clean` + `pod install` (after Podfile / native-plugin changes) |
| `make backend-run` | `uvicorn app.main:app --reload --host 0.0.0.0 --port 9090` |
| `make backend-test` | `pytest` from `backend/` |
| `make backend-install` | One-time backend venv + editable install |

## Testing

```bash
make test           # 69 frontend + 24 backend, currently green
make analyze        # flutter analyze (zero errors required)
```

Tests are named `FR-NNN: <description>` where `FR-NNN` maps to a Functional Requirement in `specs/001-bill-split-flow/spec.md`. The same FR can have multiple tests covering different aspects.

## Spec-driven workflow

This project uses [GitHub spec-kit](https://github.com/github/spec-kit). Active feature: [`specs/001-bill-split-flow/`](specs/001-bill-split-flow/). The Constitution (`.specify/memory/constitution.md`) is the project's law and supersedes any conflicting practice.

Five slash commands drive the flow:

1. `/speckit-specify` — capture the feature in plain English (`spec.md`).
2. `/speckit-clarify` — tighten ambiguous AC with follow-up questions.
3. `/speckit-plan` — derive the technical implementation plan (`plan.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md`).
4. `/speckit-tasks` — break the plan into dependency-ordered tasks (`tasks.md`).
5. `/speckit-implement` — execute the tasks in order.

Key Constitution principles (non-negotiable):

- **Spec-Driven Development** — every code change traces to a written spec.
- **Test-First Discipline** — write failing tests first, named `FR-NNN: …`, confirm they fail for the right reason, then implement.
- **Verifier-Gated Completion** — an independent verifier sub-agent flips status to `done`.
- **Ask, Don't Assume** — if something is ambiguous, ask the user instead of pre-filling defaults.

## Security

Three non-negotiable rules (Constitution v1.1.0):

1. **`GEMINI_API_KEY` never ships inside the Flutter app build.** It lives only in the backend's runtime environment.
2. **Every app → backend request carries a Firebase Anonymous Auth ID token** in the `Authorization: Bearer <token>` header. The backend verifies the token via `firebase-admin` before invoking Gemini.
3. **The backend is never deployed publicly without auth.** The 401-on-missing-token gate is the only thing preventing arbitrary callers from burning the Gemini quota.

The Firebase Admin service-account JSON (`backend/firebase-admin.json`) is a real secret — it's gitignored and must never be committed.

## Deploying

- **Backend → Cloud Run**: `backend/Dockerfile` is multi-stage Python 3.12; `gcloud run deploy` with the env vars from `.env` brings it up. Free tier covers personal use (2M req/month, scale-to-zero).
- **Frontend → TestFlight**: enroll in the Apple Developer Program ($99/yr), archive in Xcode, upload to App Store Connect, install via TestFlight on the phone. Builds last 90 days per upload.

The free Apple-ID signing path also works for personal use but requires a re-sign every 7 days.

## License

TBD.
