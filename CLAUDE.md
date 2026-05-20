# Working in this project

This is a Flutter mobile app (iOS + Android) — a bill splitter for Egyptian restaurants — with a stateless Python (FastAPI) backend that proxies image-extraction calls to Gemini 2.5 Flash. Frontend code lives in `frontend/`, backend code in `backend/`. The authoritative project rules live in `.specify/memory/constitution.md`; the active feature plan is referenced at the bottom of this file.

## Spec-driven workflow (spec-kit)

This project uses [GitHub spec-kit](https://github.com/github/spec-kit) for spec-driven development. The slash-command flow:

1. **`/speckit-specify`** — capture the feature in plain English; produces `specs/<NNN-feature>/spec.md`.
2. **`/speckit-clarify`** — optional pass to ask follow-up questions and tighten ambiguous AC.
3. **`/speckit-plan`** — derive the technical implementation plan from the spec; produces `plan.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md`.
4. **`/speckit-tasks`** — break the plan into actionable, dependency-ordered tasks; produces `tasks.md`.
5. **`/speckit-implement`** — execute the tasks in order, marking each `[ ]` → `[x]` as it completes.

The Constitution (`.specify/memory/constitution.md`) is the project's law; it supersedes any spec-kit default that conflicts with it. See the next section for the most important override.

## Spec-kit interoperability — Constitution wins

When invoking ANY spec-kit slash command (`/speckit-specify`, `/speckit-clarify`, `/speckit-plan`, `/speckit-tasks`, `/speckit-implement`, etc.), spec-kit's default rules — including its "make informed guesses based on industry standards" and its "max 3 [NEEDS CLARIFICATION] markers" cap — DO NOT APPLY. They are overridden by the project's Constitution, specifically **Principle IV: Ask, Don't Assume**.

Concretely, when running any spec-kit drafting command:

1. **Read `.specify/memory/constitution.md` before anything else** in the skill workflow.
2. For every piece of information that the spec-kit template asks you to fill (User Story, AC, Non-goals, FRs, Success Criteria, Assumptions, etc.): if the user did not explicitly state it in their `/speckit-*` input or in source documents they pointed at, STOP and ask them via `AskUserQuestion` (grouped, ≤4 at a time, batched but never deferred to "keep batches tidy").
3. **The "max 3 [NEEDS CLARIFICATION] markers" cap is removed.** Use as many as needed.
4. **After writing the initial draft**, AS A SEPARATE STEP, sweep the document for every line that came from your own guess rather than the user's explicit input, and surface each as a question. This step is automatic, not user-prompted.
5. If the user explicitly says "use your judgment" / "you decide", record the deferral in the Assumptions or Context section. Silent guesses are forbidden.

Spec-kit's `/speckit-clarify` is still useful as an additional clarification pass after the initial draft, but it is NOT the only place where clarification happens — the ask-first behavior is the rule for every spec-kit drafting command.

## Flutter-specific conventions (`frontend/`)

- **Test runner**: `flutter test` (full suite) or `flutter test test/path/foo_test.dart` (single file). Run from `frontend/` or use the top-level `make frontend-test` target.
- **Static analysis**: `flutter analyze` (or `make frontend-analyze`). Zero errors required before any task is marked done.
- **Source layout**: implementation under `frontend/lib/`, tests under `frontend/test/`. Mirror the directory structure between the two.
- **State management**: pragmatic — start with in-memory holders injected via constructor. No state-management package is currently in use; introducing one requires an explicit decision recorded in a spec.
- **Theme**: Material 3 with `ColorScheme.fromSeed(seedColor: 0xFF1976D2)` (royal blue) and surface override `0xFFFAF8F4` (off-white). See `frontend/lib/theme.dart`.
- **Test naming**: `FR-NNN: <description>` where `FR-NNN` maps to a Functional Requirement in the active feature's `spec.md`.

## Backend-specific conventions (`backend/`)

- **Test runner**: `pytest` from `backend/` (or `make backend-test`).
- **Local run**: `uvicorn app.main:app --reload --port 8080` (or `make backend-run`). Needs a real `GEMINI_API_KEY` and `FIREBASE_PROJECT_ID` in `backend/.env`.
- **Source layout**: `backend/app/{routes, services, models, auth}/`; tests under `backend/tests/`.
- **Non-negotiable security rules** (Constitution v1.1.0):
  - `GEMINI_API_KEY` lives ONLY in the backend environment; NEVER in the Flutter app build.
  - Every app → backend request carries a Firebase Anonymous Auth ID token, verified server-side via `firebase-admin`.

## Build & run shortcuts

The top-level `Makefile` delegates to `frontend/` and `backend/`:

| Target | What it does |
|---|---|
| `make test` | `flutter test` + `pytest` |
| `make analyze` | `flutter analyze` |
| `make frontend-run-ios` | Run the app on the iPhone simulator |
| `make frontend-run-android` | Run the app on the Android emulator |
| `make backend-run` | uvicorn locally on http://localhost:8080 |
| `make backend-test` | pytest |
| `make backend-install` | One-time backend venv setup |

<!-- SPECKIT START -->
**Active spec-kit feature plan**: [`specs/001-bill-split-flow/plan.md`](specs/001-bill-split-flow/plan.md)

For technologies, project structure, shell commands, and other implementation context for the current feature, read the plan above (and the sibling `research.md`, `data-model.md`, `quickstart.md`, `contracts/` files in the same directory). The plan is the authoritative source for tech choices for this feature; the constitution (`.specify/memory/constitution.md`) is authoritative for project-wide rules.
<!-- SPECKIT END -->
