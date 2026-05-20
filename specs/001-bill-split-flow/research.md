# Phase 0 Research: Bill Split Flow

Each entry below records a technical decision with its rationale and the alternatives considered. Every decision traces to a specific user answer during the `/speckit-plan` clarification rounds (2026-05-19) or to a constitutional rule, never to a silent default.

## R-1: Backend language and framework

- **Decision**: Python 3.12 + FastAPI + `uvicorn`
- **Rationale**: User chose Python + FastAPI in `/speckit-plan` round 1 and Python 3.12 in round 4 (2026-05-19). FastAPI provides async I/O, automatic OpenAPI generation, Pydantic-backed request/response validation, and clean integration with the official `google-generativeai` Python SDK.
- **Alternatives considered**:
  - **Node.js + Fastify**: rejected — user explicitly chose Python.
  - **Dart server (Dart Frog / Shelf)**: rejected — smaller ecosystem; user did not select.
  - **Python 3.11 / 3.13**: rejected — user picked 3.12 for the perf improvements without the bleeding-edge wheel-availability risk of 3.13.

## R-2: Backend hosting

- **Decision**: Google Cloud Run free tier
- **Rationale**: User chose Cloud Run free tier in round 2 (2026-05-19) after stating "we need something that is free". Free quotas — 2M requests / 360k vCPU-seconds / 180k GiB-seconds per month — comfortably cover the v1 use case (~5–20 receipts/month). Scales to zero between requests so there is no idle cost. Same GCP account as the Gemini API simplifies billing if the user later exceeds the free tier.
- **Alternatives considered**:
  - **Render.com free tier**: rejected — its free web service sleeps after 15 minutes idle and the cold-start penalty (~30 seconds) is unacceptable for an interactive mobile flow.
  - **Oracle Cloud Free Tier ARM VM**: rejected — more ops surface; user wanted minimal setup.
  - **Vercel / Netlify functions**: rejected — Node-only runtime.

## R-3: App → backend authentication

- **Decision**: Firebase Anonymous Authentication, ID token attached to every request
- **Rationale**: User chose Anonymous Firebase Auth in round 1 (2026-05-19). Provides a real cryptographic gate without exposing user accounts. Firebase issues an anonymous client a stable UID + a short-lived ID token (JWT signed by Firebase). The backend verifies the token using `firebase-admin`; an attacker without a valid Firebase project ID cannot mint a valid token.
- **Setup steps the user owns** (also in [quickstart.md](quickstart.md)):
  1. Create a Firebase project at <https://console.firebase.google.com>.
  2. Enable Authentication → Sign-in method → **Anonymous**.
  3. Register iOS and Android apps in the project; download `GoogleService-Info.plist` → `frontend/ios/Runner/`, and `google-services.json` → `frontend/android/app/`.
  4. Generate a backend service-account JSON (Project Settings → Service Accounts → Generate new private key) → save as `backend/firebase-admin.json` (gitignored).
- **Alternatives considered**:
  - **Static shared secret in the app build**: rejected — the secret is reverse-engineerable from a real APK/IPA, so the gate is effectively no better than no auth.
  - **No auth (trust by obscurity)**: rejected — anyone discovering the backend URL can burn the Gemini quota.
  - **Per-user accounts**: rejected — the spec's Assumptions section says authentication and accounts are out of scope for v1.

## R-4: Frontend HTTP client

- **Decision**: Keep `dio` (already in `pubspec.yaml`)
- **Rationale**: `dio` is already the HTTP client in the existing frontend. It supports interceptors, which let us attach the Firebase ID token to every outgoing request in one place. Constitution v1.1.0 explicitly lists `dio` in the frontend stack.
- **Alternatives considered**:
  - **`http` package**: rejected — less ergonomic; would need a manual wrapper for the auth interceptor.
  - **`chopper` / `retrofit`**: rejected — code generation overhead is overkill for one endpoint.

## R-5: Responsive Flutter layout

- **Decision**: `LayoutBuilder` + explicit breakpoints, combined with `MediaQuery.of(context).size` for current dimensions
- **Rationale**: User chose phones + tablets, both orientations in round 3 (2026-05-19). Flutter's `LayoutBuilder` gives explicit per-widget control over which layout variant to build. Material 3 does not prescribe a specific pattern.
- **Breakpoints**:
  - **Phone portrait**: width < 600
  - **Phone landscape / small tablet**: 600 ≤ width < 900
  - **Tablet (either orientation)**: width ≥ 900
- **Alternatives considered**:
  - **`flutter_screenutil`**: rejected — scales by ratio; does not help with structural layout changes (e.g., column count).
  - **`responsive_framework`**: rejected — more opinionated than needed; another dep to maintain.

## R-6: Material 3 theme (royal blue + off-white)

- **Decision**:
  - Seed color: `Color(0xFF1976D2)` (Material Blue 700, royal blue)
  - Background / surface override: `Color(0xFFFAF8F4)` (warm off-white)
  - Use `ColorScheme.fromSeed(seedColor: ..., brightness: Brightness.light)`, then `.copyWith(surface: ..., background: ...)` to lock in the off-white
- **Rationale**: User chose Material Blue 700 + warm off-white in round 3 (2026-05-19). Material 3's seed-based color generation produces a coherent palette; surface override avoids the default white that the user specifically wanted to avoid.
- **Alternatives considered**:
  - **Hand-pick all 25+ Material 3 color roles**: rejected — too brittle; defeats the seed-based system.
  - **Material 2 theme**: rejected — loses adaptive Material 3 widgets and the modern look the user implied.
  - **Pure dark theme**: rejected — user picked the warm off-white over dark navy.

## R-7: Loading-spinner pattern

- **Decision**: Per-screen inline `CircularProgressIndicator` driven by a `_phase` enum
- **Rationale**: User chose inline (per-screen) spinners in round 3 (2026-05-19). Each screen owns its own loading state; no global modal overlay.
- **Pattern** (matches existing `ExtractionScreen`):
  - Screen state has a `_phase` enum: `idle | loading | success | error`
  - `build` switches on `_phase`
  - `loading` returns `const Center(child: CircularProgressIndicator())`
- **Alternatives considered**:
  - **Global modal overlay**: rejected by user.
  - **Skeleton-list shimmer**: out of scope for v1; could be added later as a polish story.

## R-8: Existing-stories disposition

- **Decision**: STORY-001, STORY-002, STORY-003 are SUPERSEDED by this plan. They remain in `specs/features/` for audit history but no longer drive development.
- **Rationale**: User chose "treat existing work as throwaway, restart per new plan" in round 2 (2026-05-19). The new architecture (backend tier, Firebase Auth) invalidates STORY-002's direct-Gemini approach; the cleanest mental model is supersession rather than per-story amendments.
- **What survives**: the actual Dart code for the People and Capture screens migrates into `frontend/lib/screens/` unchanged. Only the ExtractionScreen's call path changes (Gemini direct → backend HTTP).
- **Alternatives considered**:
  - **Amend each existing story in place** (like we did for STORY-001's duplicate-detection change): rejected by user.
  - **Hard-delete the existing STORY files**: not needed; keeping them as historical artifacts is harmless.

## R-9: Constitution amendment

- **Decision**: Bump constitution from v1.0.0 → v1.1.0 in this change-set, BEFORE any implementation work begins
- **Rationale**: User chose "amend NOW, before implementing anything" in round 4 (2026-05-19). The constitution explicitly forbids implementation without a matching ratified amendment; doing it before code keeps the principle intact.
- **Changes**: a new "Backend stack" subsection under Technology Constraints + three Non-negotiable security rules + an amendment log entry. Version line updated to 1.1.0.
- **Alternatives considered**:
  - **Amend in parallel with implementation**: rejected by user — slight risk that code lands before constitution catches up.
  - **Defer the amendment**: rejected by user; explicitly violates the constitution's own governance rule.

## R-10: Backend folder layout

- **Decision**: `backend/app/{routes, services, models, auth}/ + backend/tests/`
- **Rationale**: User chose this layout in round 4 (2026-05-19). It is the standard FastAPI service pattern: HTTP layer in `routes/`, business logic in `services/`, Pydantic models in `models/`, auth concerns isolated in `auth/`. Easy to find things; mirrors typical Python backend codebases.
- **Alternatives considered**:
  - **Flat `src/`**: rejected by user — too little structure if the backend grows.
  - **Domain-driven `app/extraction/{routes, service, model}`**: rejected by user — premature for one endpoint.
