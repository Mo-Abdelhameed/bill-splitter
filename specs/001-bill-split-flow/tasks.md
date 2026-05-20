---
description: "Task list for implementing 001-bill-split-flow"
---

# Tasks: Bill Split Flow

**Input**: Design documents from `specs/001-bill-split-flow/`

**Prerequisites**: plan.md (loaded), spec.md (loaded), research.md (loaded), data-model.md (loaded), contracts/backend-api-v1.md (loaded), quickstart.md (loaded)

**Tests**: REQUIRED for every task that introduces behavior. Constitution Principle II ("Test-First Discipline") is NON-NEGOTIABLE — every behavioral test is written first and confirmed failing before its implementation.

**Test naming convention** (user choice, 2026-05-19): `FR-NNN: <description>` where `FR-NNN` is the Functional Requirement from `spec.md`. Multiple tests may share an FR prefix when they verify different aspects of the same FR.

**Organization**: Tasks are grouped by user story (US1=P1, US2=P2, US3=P3) so each story is independently implementable and testable.

## Format: `[ID] [P?] [Story?] Description`

- `[P]` — can run in parallel (different files, no dependency on incomplete prior task)
- `[Story]` — `US1` / `US2` / `US3` for user-story-phase tasks only
- Each task names exact file paths.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Restructure the repo and bring up the empty backend skeleton. No user-story behavior here.

- [x] T001 Move existing Flutter scaffold into `frontend/` via a single `git mv` commit. Move `lib/`, `test/`, `ios/`, `android/`, `pubspec.yaml`, `pubspec.lock`, `analysis_options.yaml`, `Makefile`, `.env`, `.env.example`, `bill_split.iml`, `.metadata` from the repo root into `frontend/`. Update `frontend/Makefile` so every `flutter` invocation runs `cd <repo-root>/frontend && flutter …` (the targets stay the same names; the working directory changes). DO NOT move `specs/`, `.specify/`, `.claude/`, `CLAUDE.md`, `README.md`, `.gitignore`, `.git/` — those stay at the repo root.
- [x] T002 ~~[P] Mark STORY-001, STORY-002, STORY-003 as superseded by `001-bill-split-flow`~~ — **N/A**: the custom-system STORY files (and the `scripts/spec/regen-index` script) were intentionally removed from disk by the user (2026-05-19), confirming the "treat as throwaway" direction. The supersession is now implicit by deletion; no header edits are needed.
- [x] T003 Create `backend/` directory at the repo root with the subtree: `backend/app/{routes,services,models,auth}/`, `backend/tests/`. Add `backend/pyproject.toml` declaring Python 3.12, FastAPI, uvicorn, google-generativeai, firebase-admin, pydantic, python-multipart, pillow; dev-deps pytest + httpx (for FastAPI test client).
- [x] T004 [P] Create `backend/.env.example` with placeholders for `GEMINI_API_KEY`, `FIREBASE_PROJECT_ID`, `GOOGLE_APPLICATION_CREDENTIALS`. Create `backend/.env` from it locally (gitignored). Update root `.gitignore` to include `backend/.env`, `backend/.venv/`, `backend/__pycache__/`, `backend/**/__pycache__/`, `backend/*.egg-info/`, `backend/.pytest_cache/`.
- [x] T005 [P] Create `backend/Dockerfile` (multi-stage, Python 3.12 base, install pyproject, expose 8080, run uvicorn `app.main:app --host 0.0.0.0 --port 8080`). Create `backend/.dockerignore` to exclude `.env`, `firebase-admin.json`, `__pycache__`, `.pytest_cache`, tests, `.venv`.
- [x] T006 Update top-level `Makefile` (or create one at the repo root that delegates) with new targets: `frontend-test`, `frontend-analyze`, `frontend-ios`, `frontend-android`, `backend-test`, `backend-run`. The existing `frontend/Makefile` continues to handle Flutter-specific targets.

**Checkpoint**: Repo structure matches `plan.md`'s "Project Structure → Source Code" tree. `flutter test` (full suite) still passes from `frontend/` after the move. `pytest backend/` runs (zero tests yet) without errors.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Theme, routing, Firebase initialization, FastAPI skeleton, auth verification, request models. ALL user stories depend on this phase.

⚠️ **CRITICAL**: No user-story work can begin until this phase is complete.

### Foundational tests (write first, confirm failing)

- [x] T007 [P] Write failing backend test for the Firebase token verifier in `backend/tests/test_firebase_auth.py`. Test cases:
  - `FR-002: missing Authorization header returns 401 with error code "unauthorized"`
  - `FR-002: malformed token returns 401 with error code "unauthorized"`
  - `FR-002: expired/invalid-signature token returns 401 with error code "unauthorized"`
  - `FR-002: valid token returns the verified Firebase UID`
  Use a fake `firebase-admin` (monkeypatch `firebase_admin.auth.verify_id_token`).

- [x] T008 [P] Write failing backend test for `/v1/health` in `backend/tests/test_health_route.py`. One test: `health endpoint returns 200 with {"status": "ok"}`.

- [x] T009 [P] Write failing frontend test for the Material 3 theme in `frontend/test/theme_test.dart`. Test cases:
  - `theme: primary seed color is 0xFF1976D2`
  - `theme: surface color is 0xFFFAF8F4 (off-white)`
  - `theme: useMaterial3 is true`

- [x] T010 [P] Write failing frontend test for the responsive-breakpoint utility in `frontend/test/utils/breakpoints_test.dart`. Test cases:
  - `breakpoints: width 320 returns Breakpoint.phonePortrait`
  - `breakpoints: width 600 returns Breakpoint.phoneLandscapeOrSmallTablet`
  - `breakpoints: width 900 returns Breakpoint.tablet`
  - `breakpoints: width 1200 returns Breakpoint.tablet`

- [x] T011 [P] Write failing frontend test for the `LoadingState` widget in `frontend/test/widgets/loading_state_test.dart`. Test cases:
  - `LoadingState: with phase=loading renders a centered CircularProgressIndicator`
  - `LoadingState: with phase=idle renders the child widget`
  - `LoadingState: with phase=error renders the error child`

### Foundational implementation

- [x] T012 Implement Material 3 theme at `frontend/lib/theme.dart`: seed color `Color(0xFF1976D2)`, surface override `Color(0xFFFAF8F4)`, both light and dark schemes (dark scheme can be auto-derived from `Brightness.dark`).

- [x] T013 [P] Implement responsive-breakpoint utility at `frontend/lib/utils/breakpoints.dart`. Provide an enum `Breakpoint` with `phonePortrait`, `phoneLandscapeOrSmallTablet`, `tablet`, and a free function `breakpointFor(BuildContext) → Breakpoint` that reads `MediaQuery.of(context).size.width` and applies the 600/900 cuts.

- [x] T014 [P] Implement `LoadingState` widget at `frontend/lib/widgets/loading_state.dart`: takes a `phase` enum and a `child` builder. `loading` → `Center(child: CircularProgressIndicator())`. `idle/success` → `child`. `error` → an `errorChild` builder.

- [x] T015 Add Firebase Flutter dependencies to `frontend/pubspec.yaml` (`firebase_core`, `firebase_auth`). Run `flutter pub get` from `frontend/`. Initialize Firebase in `frontend/lib/main.dart` via `Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform)` before `runApp`. Sign in anonymously on launch and obtain the ID token; expose it to `BackendClient` via the `idTokenProvider` constructor callback. `firebase_options.dart` was generated by `flutterfire configure` for the `bill-splitter-7e7f5` Firebase project (2026-05-19) — Android `google-services` plugin was auto-wired in the Android Gradle config.

- [x] T016 Implement `BackendClient` at `frontend/lib/services/backend_client.dart`: wraps `dio`; adds a request interceptor that attaches `Authorization: Bearer <id-token>` to every outgoing request; the token comes from an injected `IdTokenProvider` callback (real impl wires to `FirebaseAuth.instance.currentUser?.getIdToken()` in Phase 3). Base URL from constructor; main.dart will pass `--dart-define=BACKEND_URL` value in Phase 3.

- [x] T017 Implement Pydantic models at `backend/app/models/extraction.py`: `ExtractedItem`, `ExtractionResponse`, `ErrorResponse` exactly per `contracts/backend-api-v1.md`.

- [x] T018 Implement Firebase token verification at `backend/app/auth/firebase.py`: a `verify_firebase_token(authorization_header: str) → uid: str` function that uses `firebase_admin.auth.verify_id_token`. Initialize the Firebase Admin SDK once (idempotent) using `GOOGLE_APPLICATION_CREDENTIALS` env var. Raise a typed exception on failure that the FastAPI dependency translates to a 401 with `error: "unauthorized"`.

- [x] T019 Implement FastAPI app skeleton at `backend/app/main.py` and `backend/app/config.py`. `config.py` loads env vars (`GEMINI_API_KEY`, `FIREBASE_PROJECT_ID`, `GOOGLE_APPLICATION_CREDENTIALS`). `main.py` creates the `FastAPI` instance, mounts the `/v1/health` and `/v1/extract` routers, wires the Firebase auth dependency.

- [x] T020 Implement `/v1/health` route at `backend/app/routes/health.py`: returns `{"status": "ok"}`. No auth required for this endpoint.

- [x] T021 Implement `/v1/extract` route STUB at `backend/app/routes/extract.py`: accepts multipart `image`, requires Firebase auth, currently returns canned data: `{"items": [{"name": "stub item", "price": 0.0}], "tax": null, "service": null}`. Real Gemini call comes in T034/T035.

- [x] T022 Define the frontend extraction-service interface at `frontend/lib/services/extraction_client.dart`: an abstract `ExtractionClient` (replaces the old `GeminiExtractor` interface for spec-kit usage) with `Future<ExtractionResult> extract(Uint8List imageBytes)`. Implement `BackendExtractionClient` that calls `BackendClient.dio.post('/extract', multipart: image)` and parses the response into `ExtractionResult`. Map non-2xx responses to the extended `ExtractionFailure` enum (added `unauthorized` per `contracts/backend-api-v1.md`).

**Checkpoint**: All T007–T011 tests now pass after T012–T022 land. `flutter analyze` clean. `pytest backend/` green. Foundation ready — user story work can begin in parallel.

---

## Phase 3: User Story 1 — Split a paper receipt among friends (P1) 🎯 MVP

**Goal**: A user enters names, captures a receipt, sees extracted items, drags people onto items, and gets per-person totals.

**Independent Test**: A non-technical user with a paper receipt and a group of names can complete the full split flow end-to-end. The sum of per-person totals equals the bill total. (Spec SC-001 + SC-002.)

### Tests for US1 (write first, confirm failing)

- [x] T023 [P] [US1] Rename existing frontend tests to FR-NNN convention as part of moving them to `frontend/test/`. Drop `frontend/test/services/gemini_extractor_test.dart` (the old direct-Gemini parser is replaced by backend tests). For the remaining test files, rewrite each `testWidgets` / `test` name from `STORY-NNN AC-N: …` to `FR-NNN: …` per the mapping below; do NOT change the test bodies.
  Files and mapping:
  - `frontend/test/screens/people_screen_test.dart` (7 tests) → `FR-001` for the entry/add/remove behaviors, `FR-017` for the duplicate-detection tests, `FR-011`-adjacent for Continue gating.
  - `frontend/test/screens/capture_screen_test.dart` (10 tests) → `FR-002` for the camera/gallery/preview behaviors.
  - `frontend/test/services/image_resizer_test.dart` (3 tests) → `FR-002` (image-resize precondition before upload).
  - `frontend/test/widget_test.dart` → `FR-smoke: app boots without exception`.

- [x] T024 [P] [US1] Rewrite `frontend/test/screens/extraction_screen_test.dart` from scratch under the new architecture. Inject a fake `ExtractionClient` (not the old `GeminiExtractor`). Tests:
  - `FR-002: initial state shows image preview, "Extract items" button, no items list, no extractor call yet`
  - `FR-002: tap Extract triggers exactly one backend call with the image bytes; loading state shows`
  - `FR-003: successful response renders editable items list`
  - `FR-012: editing name/price updates in-screen state`
  - `FR-014: deleting a row removes it`
  - `FR-013: Add item appends a row with name="" price=0`
  - `FR-004: tax non-null shows checked Tax checkbox with editable amount`
  - `FR-004: tax null shows unchecked checkbox, no amount input`
  - `FR-004: service non-null shows checked Service checkbox with editable amount`
  - `FR-004: service null shows unchecked checkbox, no amount input`
  - `FR-004: unchecking a checked checkbox removes the amount and nulls in-screen state`
  - `FR-004: checking an unchecked checkbox shows amount input defaulting to 0`
  - `FR-015: extraction failure shows error message + Retry + Enter items manually buttons; Retry re-issues; manual fallback enters empty editable state`
  - `FR-016: Continue is enabled iff items list contains ≥1 trimmed non-empty name`
  - `FR-008: Continue commits items/tax/service to bill state and triggers navigation`
  - `FR-002: 401 from backend maps to ExtractionFailure.unauthorized and surfaces a re-auth prompt`

- [x] T025 [P] [US1] Write failing tests for the NEW Assignment screen at `frontend/test/screens/assignment_screen_test.dart`. Tests:
  - `FR-005: each item row exposes a drop-target; people are draggable from the people-strip at the bottom`
  - `FR-005: alternative tap path — tapping an item opens a modal with per-person checkboxes`
  - `FR-006: a person dropped onto multiple items is recorded against each`
  - `FR-006: an item with multiple assignees shows multiple avatar chips on its row`
  - `FR-007: by default, an item with N assignees splits equally (weight=1 each)`
  - `FR-007a: editing the weight of one assignee changes their share proportionally`
  - `FR-011: Continue is disabled while ANY item has zero assignees`
  - `FR-011: a visual indicator marks unassigned items`
  - `FR-008: Continue commits the assignment map to bill state and navigates to /totals`

- [x] T026 [P] [US1] Write failing tests for the NEW Totals screen at `frontend/test/screens/totals_screen_test.dart`. Tests:
  - `FR-016: every person from the bill is rendered as a card with their name + total`
  - `FR-008: sum of per-person totals equals the bill total (items + tax + service)`
  - `FR-007: with equal-split assignees, each assignee pays an exact equal share`
  - `FR-007a: with weighted assignees (2:1), the heavier-weight assignee pays 2/3 of that item`
  - `FR-009: when tax is marked included, no additional tax is added on top`
  - `FR-010: when tax is marked not-included, each person's total includes their proportional share of tax added on top`
  - `FR-009 + FR-010: same pair for service`
  - `FR-008: rounding residual (sub-currency-unit difference) is displayed, not silently distributed`

- [x] T027 [P] [US1] Write failing backend integration tests at `backend/tests/test_extract_route.py` (replacing the stub from T021's contract):
  - `FR-002: POST /v1/extract without Authorization header returns 401 with error="unauthorized"`
  - `FR-002: POST /v1/extract with malformed token returns 401`
  - `FR-002: POST /v1/extract with no image part returns 400 with error="bad_image"`
  - `FR-002: POST /v1/extract with image > 5MB returns 413 with error="image_too_large"`
  - `FR-002: POST /v1/extract with content-type other than image/jpeg|png returns 415 with error="bad_image"`
  - `FR-003: success path — mock Gemini returns valid JSON; route returns 200 with parsed items`
  - `FR-015: Gemini network failure (mocked) returns 502 error="network"`
  - `FR-015: Gemini schema-violation response returns 500 error="schema"`
  - `FR-015: Gemini empty items array returns 500 error="empty"`
  Use FastAPI's `TestClient` + monkeypatch on the Gemini service.

- [x] T028 [P] [US1] Write failing backend unit tests for the Gemini service at `backend/tests/test_gemini_service.py`:
  - `FR-003: extract(image_bytes) returns ExtractionResponse on success — fixture image, mocked SDK response`
  - `FR-003: quantity-expansion semantics — three pasta items each at 50 when receipt shows "pasta × 3 @ 150"` (constructed via the prompt + mocked response)
  - `FR-003: null tax/service — when Gemini returns null fields, the parsed response has them as None`
  - `FR-015: SDK raises a network exception → service raises typed `NetworkError`
  - `FR-015: malformed JSON → service raises typed `ParseError`
  - `FR-015: missing items key → service raises typed `SchemaError`

### Implementation for US1

- [x] T029 [US1] Refactor `frontend/lib/screens/extraction_screen.dart` to use `ExtractionClient` (from T022) instead of `GeminiExtractor`. Preserve the existing pre/loading/editable/error phase machine. Add the `unauthorized` failure-mode UI branch (re-auth prompt) per the rewritten test in T024.

- [x] T030 [US1] Implement the new `AssignmentScreen` at `frontend/lib/screens/assignment_screen.dart`. Composition:
  - Top half: list of items (from `billState.items`); each row a drop-target for `Draggable<personId>`.
  - Bottom strip: horizontally scrollable list of people chips, each `Draggable<personId>`.
  - Tap path: tap an item → modal sheet with per-person checkboxes (FR-005 fallback).
  - Per-item weight editor: long-press an assignee chip on an item → small popover with a weight input (default 1).
  - Continue button: disabled until every item has ≥1 assignee.

- [x] T031 [US1] Implement the new `TotalsScreen` at `frontend/lib/screens/totals_screen.dart`. Computes per-person totals from `billState` per the math in `data-model.md` (item.share_for(personId) + tax_share + service_share). Renders one card per person with name + items they're paying for + breakdown + grand total. Shows a residual line if rounding leaves a fraction.

- [x] T032 [US1] Wire new routes into `frontend/lib/router.dart`: add `/assign` → `AssignmentScreen`, `/totals` → `TotalsScreen`. Remove the placeholder `assignment_screen.dart` from STORY-003. Update `frontend/lib/screens/extraction_screen.dart`'s onContinue to navigate to `/assign`.

- [x] T033 [US1] Add the `unauthorized` case to `ExtractionFailure` enum in `frontend/lib/services/extraction_client.dart` (it already exists in `gemini_extractor.dart`; the new file is the destination). Update mapping logic + UI per T024's expectations. (Enum + mapping landed in T022; UI branch landed in T029; new FR-002 401 test in T024 verifies end-to-end behavior.)

- [x] T034 [US1] Implement the Gemini service at `backend/app/services/gemini.py` using `google-generativeai`. The service:
  - Loads `GEMINI_API_KEY` from env (via config.py).
  - Builds a request to Gemini 2.5 Flash with the receipt prompt + JSON response schema (port the prompt and schema from the deprecated `lib/services/gemini_extractor.dart`).
  - Parses the model's response into `ExtractionResponse` per the schema.
  - Raises typed errors (`NetworkError`, `ParseError`, `SchemaError`, `EmptyItemsError`) for each failure mode.
  - Logs latency (stdout) but never logs image bytes or the raw response body.

- [x] T035 [US1] Wire `/v1/extract` to the real Gemini service in `backend/app/routes/extract.py`. Validate the multipart upload (size ≤ 5MB, content-type jpeg|png), then call the Gemini service, then return the response. Map service errors to the documented HTTP status + `error` code from `contracts/backend-api-v1.md`.

- [x] T036 [US1] Remove `GEMINI_API_KEY` from the frontend: delete the line from `frontend/.env` and `frontend/.env.example`; remove the `assets: - .env` entry from `frontend/pubspec.yaml`; delete the `envValue('GEMINI_API_KEY')` call and the `GeminiExtractorImpl` instantiation from `frontend/lib/main.dart`; delete the now-unused `frontend/lib/services/gemini_extractor.dart` file. Also dropped the `flutter_dotenv` dependency since nothing reads `.env` at runtime anymore.

- [ ] T037 [US1] End-to-end smoke test (manual): boot the backend locally with a real `GEMINI_API_KEY`; boot the iPhone 17 simulator with `flutter run -d iphone --dart-define=BACKEND_URL=http://localhost:8080/v1`; enter names → capture image → extract → assign → totals. Verify the bill total matches the sum of per-person totals. Document the test in `specs/001-bill-split-flow/quickstart.md` if any steps need refinement.

**Checkpoint**: User Story 1 is fully functional. Frontend tests green. Backend tests green. `flutter analyze` clean. End-to-end smoke test passed on at least one simulator.

---

## Phase 4: User Story 2 — Recover from a failed receipt scan (P2)

**Goal**: A user whose receipt fails extraction can still complete the split via manual item entry.

**Independent Test**: With a deliberately bad image (or simulated extractor failure), the user reaches a working manual-entry items list within two taps of the failure message; the rest of the flow (assignment, totals) works identically.

### Tests for US2

- [ ] T038 [P] [US2] Add focused tests at the end of `frontend/test/screens/extraction_screen_test.dart`:
  - `FR-015: AC-14 manual-fallback transitions to an editable empty list with tax=null, service=null`
  - `FR-015: from manual-fallback, adding items via "Add item" works exactly as in the success path`
  - `FR-015: tapping Retry from the error state re-issues the backend call with the same image`

### Implementation for US2

Most of US2 was implemented as part of US1 (FR-015 in the extraction screen was already required by T029). This phase just verifies the manual fallback works correctly with the BackendExtractor and adds any missing assertions.

- [ ] T039 [US2] If T038 tests fail, fix the manual-fallback path in `frontend/lib/screens/extraction_screen.dart` so the empty editable state is reachable and behaves identically to the success path.

**Checkpoint**: Users can complete a split even when extraction fails.

---

## Phase 5: User Story 3 — Handle receipts where tax/service is added on top (P3)

**Goal**: When tax/service is NOT pre-included in item prices, the user toggles them off and the per-person totals scale up to cover the additional charges.

**Independent Test**: Given a receipt where service is listed as a separate line, the user can toggle "service not included" and see each person's total include their proportional share of the 12% service charge added on top.

### Tests for US3

- [ ] T040 [P] [US3] Add focused tests at the end of `frontend/test/screens/totals_screen_test.dart`:
  - `FR-010: service "not included" with rate 12% — sum of per-person service shares = subtotal × 0.12`
  - `FR-010: tax "not included" with rate 14% — sum of per-person tax shares = subtotal × 0.14`
  - `FR-009 + FR-010: mixed (tax included, service not included) — service is added on top; tax is already in item prices`

### Implementation for US3

- [ ] T041 [US3] Implement the calculation branch in `frontend/lib/screens/totals_screen.dart` for the not-included case: when `tax.included == false`, each person's tax share = (their items_share / total_items_share) × tax_amount. Same for service. The total per person then = items_share + tax_share + service_share. Ensure the rounding-residual line still surfaces correctly.

**Checkpoint**: All three user stories work independently and together. End-to-end test on both simulators passes for inclusive and not-included tax/service.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [ ] T042 [P] Run `flutter analyze` from `frontend/`; resolve any errors (warnings acceptable). Run `pytest` from `backend/`; all green.
- [ ] T043 [P] Smoke test on iPhone 17 simulator AND Medium_Phone Android emulator with the local backend.
- [ ] T044 [P] Update top-level `README.md` to describe the two-tier architecture, how to run locally, how to deploy backend to Cloud Run, and the Firebase project setup.
- [ ] T045 [P] Run the `quickstart.md` setup end-to-end on a fresh terminal session; if any step is off, update the doc.
- [ ] T046 [P] Tighten error-state UX in `extraction_screen.dart` so error messages reference user-friendly text (not raw enum names). Constitution Principle IV: any text added here must trace to the spec — if no spec text exists, add a small spec amendment first.
- [ ] T047 [P] Add a backend `Dockerfile` health check + memory/CPU tuning for Cloud Run free-tier deploy. Document the `gcloud run deploy` invocation in `quickstart.md`.
- [ ] T048 Verify CLAUDE.md SPECKIT markers still point at the current plan. Refresh any stale references (e.g., to `gemini_extractor.dart` which gets deleted in T036).

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (Phase 1)**: T001 blocks everything subsequent (the repo restructure must happen before any new code lands at the new paths). T002, T003, T004, T005, T006 are sub-tasks of Setup that can largely parallelize after T001.
- **Foundational (Phase 2)**: depends on Setup. T007–T011 (tests) can run in parallel. Implementation tasks T012–T022 mostly parallelize except where one depends on another's exported types (e.g., T021's stub route depends on T017's Pydantic models).
- **User Stories (Phases 3–5)**: all depend on Foundational. Can run in parallel staffing-wise.
- **Polish (Phase 6)**: depends on whichever user stories you want polished.

### User-story dependencies

- **US1 (P1)**: depends on Foundational. NOT on US2 or US3. Once Foundational is green, US1 can ship as MVP.
- **US2 (P2)**: depends on Foundational. Builds on the extraction screen from US1 but is testable separately via the same screen's failure path.
- **US3 (P3)**: depends on Foundational. Builds on the totals screen from US1 but is testable separately via the toggle behavior.

### Within each user story

- Tests are written FIRST and must FAIL before implementation (Constitution Principle II).
- For US1 specifically:
  - T029 (extraction-screen refactor) depends on T022 (BackendExtractionClient).
  - T030 (AssignmentScreen) depends on T013 (breakpoints utility) and T014 (LoadingState).
  - T031 (TotalsScreen) depends on T030 (assignment data is read from bill state).
  - T034 (Gemini service) depends on T017 (Pydantic models) and T019 (config loader).
  - T035 (extract route) depends on T034 (Gemini service) and T021 (existing stub route).
  - T036 (remove GEMINI_API_KEY from frontend) depends on T029 + T035 having shipped (backend takes over the key responsibility).

### Parallel opportunities

- All [P]-marked Setup tasks (T002, T004, T005) can run in parallel after T001.
- All [P]-marked Foundational tests (T007–T011) can run in parallel.
- Foundational impl tasks T013 (breakpoints), T014 (LoadingState), and T017 (Pydantic models) parallelize after their respective tests.
- All [P]-marked User-Story-1 tests (T023, T024, T025, T026, T027, T028) can run in parallel.
- All [P]-marked Polish tasks (T042–T047) can run in parallel.

---

## Parallel Example: User Story 1 tests

```
# All US1 test-writing tasks in parallel (different files, no cross-dependencies):
T023 (rename existing frontend tests to FR-NNN)
T024 (rewrite extraction_screen_test.dart from scratch)
T025 (write assignment_screen_test.dart)
T026 (write totals_screen_test.dart)
T027 (write backend test_extract_route.py)
T028 (write backend test_gemini_service.py)
```

---

## Implementation Strategy

### MVP path

1. Complete Phase 1 (Setup): T001–T006.
2. Complete Phase 2 (Foundational): T007–T022.
3. Complete Phase 3 (US1): T023–T037.
4. Stop. Validate the entire happy path on a simulator. This IS the MVP.

### Incremental delivery after MVP

5. Add Phase 4 (US2 manual fallback): T038–T039. Re-verify.
6. Add Phase 5 (US3 not-included tax/service): T040–T041. Re-verify.
7. Polish: T042–T048.

### Backend deployment

After local end-to-end works (T037), deploy backend to Cloud Run (see `quickstart.md` step 5). Then update the Flutter app's `BACKEND_URL` dart-define to the Cloud Run URL for non-local runs.

---

## Notes

- Test naming: `FR-NNN: <description>` (user choice 2026-05-19). The same FR can have multiple tests covering different aspects.
- Constitution Principle II is NON-NEGOTIABLE: every behavioral test is written FIRST and confirmed failing before its implementation.
- `[P]` markers reflect different files / no incomplete-prior-task dependencies. They do not promise that a real developer can or should run them simultaneously — they just describe the dependency graph.
- `frontend/.env` continues to exist for any future frontend-side env vars, but it MUST NOT contain `GEMINI_API_KEY` after T036.
- After T002 lands, the custom-system `regen-index` script will see `Superseded by:` on STORY-001/002/003 and reflect that in `specs/index.json`. The verifier sub-agent still works for any future custom-system stories — only the THREE listed are superseded, not the system.
- After the entire plan is done, decide whether to keep both spec systems (custom + spec-kit) or consolidate. That decision is OUT of scope here.
