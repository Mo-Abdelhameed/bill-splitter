# Implementation Plan: Bill Split Flow

**Branch**: `001-bill-split-flow` | **Date**: 2026-05-19 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-bill-split-flow/spec.md`

## Summary

End-to-end bill split with photo-based extraction. Architecture: a Flutter mobile app (frontend) talks to a stateless Python backend (FastAPI on Cloud Run) that proxies image-extraction requests to Gemini 2.5 Flash and returns structured item data. The Gemini API key lives only in the backend's environment; the app never sees it. Firebase Anonymous Authentication gates every backend call so anonymous-but-cryptographically-bound clients are the only callers, preventing arbitrary quota burn. The existing STORY-001/002/003 are superseded by this plan per the user's explicit decision (2026-05-19) to "treat existing work as throwaway, restart per new plan".

## Technical Context

**Language/Version**:
- Frontend: Flutter stable, Dart 3.x
- Backend: Python 3.12+

**Primary Dependencies**:
- Frontend: `go_router`, `dio`, `image_picker`, `permission_handler`, `image`, `flutter_localizations`, `intl`, `firebase_core`, `firebase_auth`
- Backend: `fastapi`, `uvicorn`, `google-generativeai`, `firebase-admin`, `pydantic`, `python-multipart`, `pillow`

**Storage**: None (backend stateless; frontend in-memory `BillState` per session)

**Testing**:
- Frontend: `flutter_test` (widget + unit)
- Backend: `pytest`

**Target Platform**:
- Frontend: iOS 13+, Android API 23+, phones AND tablets, portrait AND landscape
- Backend: Linux container on Google Cloud Run free tier

**Project Type**: Mobile app + backend API (Option 3 from the spec-kit plan template)

**Performance Goals**:
- End-to-end split in under 90 seconds happy-path (SC-001)
- Backend cold start < 5 seconds on Cloud Run free tier (scales to zero)
- Per-screen UI render < 100 ms after data is available
- Tax/service toggle re-renders within 1 second (SC-005)

**Constraints**:
- `GEMINI_API_KEY` MUST NOT appear in the Flutter app build. Constitution non-negotiable.
- Every app → backend request MUST carry a Firebase Anonymous Auth ID token. Constitution non-negotiable.
- Cloud Run free tier limits: 2M requests/month, 360k vCPU-seconds/month, 180k GiB-seconds/month memory.
- Image upload max 5 MB after the 1600 px max-long-edge resize.
- Backend is stateless (no DB) in v1.

**Scale/Scope**: Single user, ~5–20 receipts/month estimated v1 usage. Single in-flight bill at a time. No multi-tenant concerns yet.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Evaluated against `.specify/memory/constitution.md` v1.1.0:

| Principle | Status | Note |
|---|---|---|
| **I. Spec-Driven Development (NON-NEGOTIABLE)** | ✅ PASS | This plan derives from `spec.md` and the four rounds of `/speckit-plan` clarification (2026-05-19). |
| **II. Test-First Discipline (NON-NEGOTIABLE)** | ✅ PASS (process gate) | Implementation MUST write tests first. Frontend via `flutter_test`, backend via `pytest`. Every behavioral AC gets a failing test before code. |
| **III. Verifier-Gated Completion** | ⚠️ CONDITIONAL | Frontend uses existing `verifier`/`ui-verifier` agents. Backend currently has no verifier; the plan substitutes `pytest` green + integration test calling the real backend as the v1 gate. A backend verifier sub-agent is a follow-up. |
| **IV. Ask, Don't Assume** | ✅ PASS | All 16 plan decisions trace to explicit user answers in `/speckit-plan` rounds 1–4 (2026-05-19); no silent defaults. |
| **V. Mobile-First on Both Platforms** | ✅ PASS | Frontend targets iOS + Android; backend is platform-agnostic. |
| **Technology Constraints (v1.1.0)** | ✅ PASS | All tech choices match the constitution: Python 3.12, FastAPI, Cloud Run free tier, Firebase Anonymous Auth, Material 3 royal blue + off-white, etc. |
| **Security rules: API key location & app auth** | ✅ PASS | Plan enforces both: `GEMINI_API_KEY` only in backend env; every app → backend request carries a Firebase ID token. |

**Constitution amendment status**: The constitution was bumped from v1.0.0 → v1.1.0 in this same change-set to add the backend tier and the security rules. The amendment is documented in the constitution's amendment log.

## Project Structure

### Documentation (this feature)

```text
specs/001-bill-split-flow/
├── plan.md              # This file
├── research.md          # Phase 0 — tech decisions with rationale + alternatives
├── data-model.md        # Phase 1 — entities, validation rules, wire types
├── quickstart.md        # Phase 1 — how to run frontend + backend locally
├── contracts/
│   └── backend-api-v1.md  # Phase 1 — HTTP contract between frontend and backend
├── checklists/
│   └── requirements.md  # Spec-quality checklist (from /speckit-specify)
└── spec.md              # Feature spec (from /speckit-specify)
```

### Source Code (repository root)

```text
frontend/                # All existing Flutter scaffold MIGRATES here from repo root.
├── lib/                 # Dart source (was /lib/)
│   ├── main.dart
│   ├── router.dart
│   ├── theme.dart
│   ├── screens/
│   │   ├── people_screen.dart
│   │   ├── capture_screen.dart
│   │   ├── extraction_screen.dart   # Now calls backend instead of Gemini directly
│   │   ├── assignment_screen.dart   # NEW for this plan
│   │   └── totals_screen.dart       # NEW for this plan
│   ├── services/
│   │   ├── backend_client.dart      # NEW: dio + Firebase ID token interceptor
│   │   ├── image_acquirer.dart
│   │   ├── image_resizer.dart
│   │   └── extraction_client.dart   # Replaces gemini_extractor.dart's role; same abstract interface, new impl
│   └── state/
│       ├── bill_state.dart
│       └── bill_item.dart
├── test/                # Flutter tests (was /test/)
├── ios/                 # iOS native project (was /ios/), includes GoogleService-Info.plist
├── android/             # Android native project (was /android/), includes google-services.json
├── pubspec.yaml         # Flutter deps (was /pubspec.yaml)
├── pubspec.lock
├── analysis_options.yaml
├── Makefile             # Frontend make targets (was /Makefile)
└── .env.example         # Frontend env template (no GEMINI_API_KEY)

backend/                 # NEW: Python FastAPI service
├── app/
│   ├── main.py          # FastAPI app entrypoint
│   ├── config.py        # Loads env vars (GEMINI_API_KEY, FIREBASE_PROJECT_ID, etc.)
│   ├── routes/
│   │   └── extract.py   # POST /v1/extract
│   ├── services/
│   │   └── gemini.py    # Wraps google-generativeai
│   ├── auth/
│   │   └── firebase.py  # Verifies Firebase ID tokens via firebase-admin
│   └── models/
│       └── extraction.py # Pydantic request/response models
├── tests/
│   ├── conftest.py
│   ├── test_extract_route.py
│   ├── test_gemini_service.py
│   └── test_firebase_auth.py
├── pyproject.toml
├── Dockerfile           # For Cloud Run deploy
├── .dockerignore
├── .env.example         # GEMINI_API_KEY=... (template)
├── .env                 # Gitignored
└── firebase-admin.json  # Service account; Gitignored

# Project-level files (stay at repo root, do NOT move into frontend/):
specs/                   # Spec-driven artifacts (both custom STORY-* and spec-kit features)
.specify/                # Spec-kit config + memory + templates
.claude/                 # Claude Code skills, agents, hooks, settings
.git/
CLAUDE.md                # Top-level agent context
README.md
.gitignore
```

**Structure Decision**: Option 3 (Mobile app + backend API). The existing Flutter scaffold (lib/, test/, ios/, android/, pubspec.yaml, Makefile, analysis_options.yaml) migrates wholesale into a new `frontend/` directory at the repo root. A new sibling `backend/` directory holds the FastAPI service. Spec-driven artifacts (`specs/`, `.specify/`, `.claude/`) stay at the repo root since they govern the whole project, not just one tier.

## Migration plan (gradual)

User chose "gradual migration: backend stub first, then real backend" in `/speckit-plan` round 2. Step-by-step:

1. **Move Flutter into `frontend/`**. Single `git mv` commit moves lib/, test/, ios/, android/, pubspec.yaml, pubspec.lock, analysis_options.yaml, Makefile, .env.example to `frontend/`. Update `Makefile` targets to `cd frontend && flutter …`. Existing tests stay green.
2. **Add `backend/` scaffold** with FastAPI but no real Gemini call yet — `POST /v1/extract` returns canned data (e.g. one "test" item) so the frontend can be migrated to call it before Gemini is wired.
3. **Set up Firebase project** (user does this manually — see [quickstart.md](quickstart.md)). Add `firebase_core` + `firebase_auth` to frontend pubspec.
4. **Replace `GeminiExtractorImpl`** in frontend with a `BackendExtractorImpl` that HTTP-calls `POST {BACKEND_URL}/v1/extract` using `dio` + a Firebase ID token interceptor. All existing extraction-screen widget tests continue to pass — they use the abstract `GeminiExtractor` interface and inject fakes.
5. **Implement real Gemini call** in `backend/app/services/gemini.py` using `google-generativeai`. Backend tests with a mocked Gemini SDK.
6. **End-to-end smoke test**: real app, real backend (local), real Firebase token, mocked Gemini. Run on iPhone 17 simulator and Medium_Phone emulator.
7. **Remove from frontend**: `flutter_dotenv` reading `GEMINI_API_KEY`, the `.env` file's API-key line, and the `.env` entry in `pubspec.yaml`'s assets list. The key now lives ONLY in `backend/.env`.

## Existing-stories supersession

Per user decision (2026-05-19) — "treat existing work as throwaway, restart per new plan" — STORY-001, STORY-002, and STORY-003 are SUPERSEDED by this plan flow. They remain in `specs/features/` for history but no longer drive development. New work uses spec-kit's `/speckit-tasks` and `/speckit-implement` against the artifacts in `specs/001-bill-split-flow/`.

Concretely:
- **STORY-001 (people screen)**: its code under `frontend/lib/screens/people_screen.dart` survives the migration as-is. The people-screen behavior carries over.
- **STORY-002 (extraction)**: superseded. The `GeminiExtractorImpl` direct-call code is REPLACED by the backend HTTP call. Tests refactored to inject a `BackendExtractor` fake instead of a `GeminiExtractor` fake.
- **STORY-003 (capture)**: its code under `frontend/lib/screens/capture_screen.dart` survives. Same interface, no behavioral change.

The `verifier`/`ui-verifier` sub-agents continue to gate frontend story completion. For backend code, gates are: `pytest` green + integration with frontend tests.

## Complexity Tracking

> Filled because the Constitution Check flagged one conditional item plus several deviations from the prior architecture.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Constitution v1.0.0 didn't cover a backend tier | User explicitly required "API key in backend, not packaged into app" + "separate frontend and backend code each in its own folder" (2026-05-19); MINOR amendment to v1.1.0 was needed | Direct in-app Gemini call (current STORY-002 architecture) exposes the API key inside the IPA/APK and is reverse-engineerable — rejected by user. |
| Folder restructure: existing Flutter → `frontend/` | User explicitly chose "Move Flutter into frontend/" in round 1 | Keeping Flutter at repo root with a sibling `backend/` was offered as an alternative; user picked the symmetric split. |
| Discarding completed STORY-001/002/003 work | User explicitly chose "treat existing work as throwaway, restart per new plan" in round 2 | Amending each existing story to fit the new architecture would preserve history but mix old and new architectures across files; user picked the clean restart. |
| No backend verifier sub-agent yet | The custom `verifier` agent is Flutter-aware; backend code uses different tooling | A backend verifier could be authored as a follow-up; in v1 we rely on `pytest` + integration test as the gate. Recorded for future work. |
