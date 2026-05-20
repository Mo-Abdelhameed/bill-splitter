# Bill Split Constitution

## Core Principles

### I. Spec-Driven Development (NON-NEGOTIABLE)
Every code change traces to a written specification before implementation begins. A specification captures intent: who the user is, what capability they want, why it matters, and what "done" looks like expressed as observable acceptance criteria. No code reaches `main` without a corresponding spec — bug fixes included; the bug itself becomes a one-paragraph spec.

Intent is the user's. The AI's job is to structure it into testable AC, never to invent scope. When the intent is ambiguous, the AI must STOP and ASK — it must never default-fill from convention, common patterns, or assumptions about what most apps do.

### II. Test-First Discipline (NON-NEGOTIABLE)
TDD is mandatory for every `[behavioral]` acceptance criterion. Order is fixed: write the AC → write a failing test named `<spec-id> AC-N: <description>` → confirm the test fails for the right reason (missing implementation, NOT syntax / import / dependency error) → implement until green → refactor with the suite green.

Tests are the executable form of the spec. They are NEVER modified to make them pass. If a test seems wrong, the SPEC is wrong, and the spec must be amended first (with rationale recorded in Verification notes). Visual AC are exempt from unit tests; they are verified by screenshot-based judgment via `ui-verifier`.

### III. Verifier-Gated Completion
A spec is `done` only after an independent verifier — a sub-agent that runs in fresh context with no implementer bias — confirms that:
1. Every `[behavioral]` AC is satisfied by the current code, AND
2. Every `[behavioral]` AC has a passing test named with the AC's identifier, AND
3. The full `flutter test` suite is green (no regressions in pre-existing tests), AND
4. `flutter analyze` reports zero errors (warnings acceptable; suppressions are not), AND
5. Non-goals are respected (no scope creep).

The implementer cannot self-declare done. The verifier is the only authority that flips Status to `done`. For specs containing `[visual @mobile]` AC, `ui-verifier` must also pass (or the visual check is explicitly deferred with the deferral recorded).

### IV. Ask, Don't Assume
Across drafting, implementation, and verification, every line of every artifact must trace to something the user explicitly wrote, said, or answered when asked. The moment any participant senses a gap — a missing piece of intent, an ambiguous statement, a detail the source does not cover, an architectural decision the spec does not specify — they stop and ask the user. They do not pre-fill answers, even with sensible-sounding defaults. "Use your judgment" / "you decide" is an explicit deferral and must be recorded in the spec's Context section; silent decisions are forbidden.

### V. Mobile-First on Both Platforms
Bill Split is a Flutter mobile app targeting iOS 13+ and Android API 23+. Every feature must work on both platforms; iOS-only or Android-only features require explicit justification in the spec's Context. Visual AC are checked against the iPhone 17 simulator AND the Medium_Phone Android emulator via `mobile-mcp` screenshots. Cupertino/Material divergence is acceptable when it makes the platform feel native; gratuitous divergence is not.

## Technology Constraints

The Bill Split app serves the Egyptian restaurant market (and is locale-overridable for elsewhere). The app is split into two tiers — a Flutter frontend that ships to user devices and a stateless Python backend that holds the Gemini API key. Both stacks below are locked unless an amendment to this constitution explicitly removes or replaces an entry.

### Frontend stack (Flutter)

- **Framework**: Flutter (stable channel), Dart 3.x
- **Routing**: `go_router`
- **State**: Pragmatic. Start with simple in-memory holders injected via constructor; introduce a state-management package (Riverpod or similar) only when complexity makes the manual approach untenable, AND only after an explicit decision recorded in a spec.
- **HTTP**: `dio` (used for app → backend calls; the backend, NOT Gemini, is the only HTTP target the app speaks to)
- **Image picker**: `image_picker`
- **Permissions**: `permission_handler`
- **Image processing**: `image` package (1600 px max long-edge resize before any upload — see STORY-003).
- **Auth (app side)**: `firebase_auth` for Anonymous Authentication; the resulting ID token is attached to every backend request via a dio interceptor.
- **Local persistence**: TBD via future spec; bias is `hive` per the original plan but no story has committed to it yet.
- **Localization**: Flutter `intl` + ARB scaffolding; English + Arabic with full RTL support.
- **Theme**: Material 3 `ColorScheme.fromSeed(seedColor: 0xFF1976D2)` (royal blue) with surface override to `0xFFFAF8F4` (off-white) to avoid stark white.
- **Egypt locale defaults**: EGP currency, 12% service charge, 14% VAT. Each is overridable per bill, but those are the defaults.

### Backend stack (Python, added 2026-05-19, constitution v1.1.0)

The backend is a stateless HTTP service that the Flutter app calls to extract receipt items. The backend holds the Gemini API key; the app NEVER does.

- **Language**: Python 3.12+
- **Framework**: FastAPI
- **Server**: `uvicorn`
- **Vision extraction**: Gemini 2.5 Flash via `google-generativeai` (Python SDK). Same model as before; the call simply moves from the app to the backend.
- **Auth verification**: `firebase-admin` (verifies Firebase Anonymous Auth ID tokens received from the app).
- **Image handling**: Pillow (where needed beyond passthrough).
- **Testing**: `pytest`.
- **Deployment**: Google Cloud Run free tier (chosen for the 2M req/month + 360k vCPU-sec/month free quota, scale-to-zero billing, same-GCP-account billing surface for Gemini).
- **State**: STATELESS in v1 — no database, no cross-request memory, no cache. Each call independently authenticates, forwards to Gemini, parses, returns.

### Non-negotiable security rules

- **The `GEMINI_API_KEY` MUST NEVER ship inside the Flutter app build.** It is set only in the backend's runtime environment (Cloud Run env var, or a deploy-time secret manager). The Flutter app NEVER reads it; no Flutter `.env` file references it.
- **Every app → backend request MUST carry a Firebase Anonymous Auth ID token in the `Authorization: Bearer <token>` header.** The backend MUST verify the token using `firebase-admin` before invoking Gemini. Unauthenticated requests return `401`.
- **The backend MUST NOT be deployed publicly without auth.** The 401-on-missing-token gate is the only thing preventing arbitrary callers from burning the Gemini quota.

## Development Workflow & Quality Gates

Every change passes through the same gates. The custom skill suite (`spec-author`, `implement-tests`, `implement-feature`, `implement-story`, `verifier`, `ui-verifier`) and the spec-kit equivalents BOTH operate against these gates — whichever drives the change, the gates are identical:

1. A spec exists for the change (story file under `specs/features/<feature>/STORY-NNN-*.md` in the custom system, or the spec-kit `specs/<feature>/spec.md` equivalent during the migration).
2. For each `[behavioral]` AC, a failing test exists named `<spec-id> AC-N: <description>` and demonstrably fails for the right reason before any implementation is written.
3. Implementation makes the AC tests pass WITHOUT modifying the tests.
4. `flutter test` (full suite) is green — including pre-existing tests. No regressions allowed.
5. `flutter analyze` reports zero errors. No `// ignore:` suppressions, no `dynamic` to dodge type errors.
6. For specs with any `[visual]` AC: `ui-verifier` has reviewed and either passed or returned with notes that the implementer must address before re-submitting.
7. The `verifier` sub-agent has reviewed all `[behavioral]` AC and flipped Status to `done`.

Bug fixes that cross multiple specs do NOT require a new spec, but the verifier re-checks affected `done` specs after the fix and flags any regression as blocking.

Pre-commit (when configured): the full test suite passes and `scripts/spec/regen-index --check` validates the spec index.

## Governance

This constitution supersedes any conflicting practice in `CLAUDE.md`, `specs/README.md`, or skill definitions. When a conflict is discovered, this document wins until formally amended.

Amendments require:
- A written reason — one paragraph minimum in the commit message or in this file's Verification-notes-style trailer — including the user's explicit approval of the change.
- Updated `Version` and `Last Amended` lines below.
- An audit of dependent artifacts: `CLAUDE.md`, `specs/README.md`, the `spec-author` / `implement-*` skills, the `verifier` / `ui-verifier` agents, and any hook scripts. Any of these that contradict the new constitution must be updated in the same commit (or in a follow-up commit that references the amendment).

Version-bump rules follow semver semantics for governance:
- **MAJOR** — a principle is removed, reworded substantively, or made non-NON-NEGOTIABLE (or vice versa).
- **MINOR** — a new principle is added, a new section is added, or a technology in the Constraints list is added or replaced.
- **PATCH** — clarifications, typo fixes, reworded examples that do not change semantics.

The strategic plan (`specs/docs/bill_split_plan.md`) is supplementary context but does NOT override this constitution. If the plan contradicts a principle, the principle wins until the constitution itself is amended.

For runtime development guidance — what to do when starting work, where files live, naming conventions — consult `CLAUDE.md`. That file describes the operational HOW; this constitution defines the immutable WHY and WHAT.

**Version**: 1.1.0 | **Ratified**: 2026-05-19 | **Last Amended**: 2026-05-19

**Amendment log:**
- **1.1.0 (2026-05-19)** — MINOR bump per governance. Added the Backend stack subsection under Technology Constraints (Python 3.12 + FastAPI + Cloud Run free tier + Firebase Anonymous Auth) and the three Non-negotiable security rules. Trigger: user decision via `/speckit-plan` on 2026-05-19 that the Gemini API key must live in a backend and never ship in the app build. Affected artifacts: `specs/001-bill-split-flow/plan.md` (new), `CLAUDE.md` (updated agent context pointer), `specs/features/extraction/STORY-002-extract-items.md` (will be superseded by the new plan flow).
