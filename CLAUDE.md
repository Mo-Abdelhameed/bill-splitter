# Working in this project

This project does **spec-driven development**. The spec is not a markdown file — **the spec is a SQLite database** served by the `specs-mcp` MCP server. Every requirement, user story, acceptance scenario, plan decision, API contract, phase, task, and dependency lives as a row in that DB. The DB is the **single source of truth** for what the system should do.

Before you write a single line of implementation code, you read from the DB. Before you mark anything done, you write to the DB. Markdown is not authoritative anywhere in this project; if you need a `.md` view of the spec, you generate one on demand from the DB.

This is a Flutter mobile app (iOS + Android) — a bill splitter for Egyptian restaurants — with a stateless Python (FastAPI) backend that proxies image-extraction to Gemini 2.5 Flash. The app code itself is **not present in this repo yet** — it will be (re)built from the DB via the workflow below.

## The specs DB (THE source of truth)

**Server:** `specs-mcp` (Python MCP server at `/Users/mo/Desktop/specs-mcp/`, registered in [.mcp.json](.mcp.json)).

**File:** `/Users/mo/Desktop/specs-mcp/specs.db` (SQLite).

**Schema:** auto-loaded as the MCP resource `specs-db://schema`. **Read it at the start of every session** before calling any write tool. It tells you every table, column type, enum (`status`, `priority`, `tier`), foreign key, and `unique` constraint. The full DDL is also available at `specs-db://schema.sql`.

What lives in the DB (the entire spec, end to end):

| Table | What it holds | Owning skill |
|---|---|---|
| `project`, `constitution_principle` | Project + the project's law (5 principles) | (bootstrap) |
| `feature` | One row per spec-kit feature (e.g. `001-bill-split-flow`) | `/speckit-specify` |
| `user_story`, `acceptance_scenario` | User-facing flows + their Given/When/Then proofs | `/speckit-specify` |
| `functional_requirement`, `success_criterion` | FR-NNN and SC-NNN rules | `/speckit-specify` |
| `edge_case`, `assumption`, `key_entity` | Failure modes, deliberate deferrals, domain nouns | `/speckit-specify` |
| `plan` (one row per feature; blob columns `summary`, `technical_context`, `project_structure`, `research`, `data_model`, `quickstart`) | What used to be plan.md / research.md / data-model.md / quickstart.md | `/speckit-plan` |
| `api_endpoint` | Backend HTTP contract (one row per endpoint) | `/speckit-plan` |
| `checklist` | Quality checklists scoped to a feature | `/speckit-specify` + `/speckit-plan` |
| `phase`, `task`, `task_dependency` | The work breakdown — Setup → Foundational → US1 → US2 → US3 → Polish | `/speckit-tasks`, `/speckit-implement` |

**Core read tools:** `get_feature(slug)`, `list_features()`, `get_constitution(project)`, `list_tasks(feature, …)`, `next_tasks(feature)`, `get_task(code)`, `search(query)`, `grep(pattern)`, `describe_schema(table?)`.

**Core write tools:** `create_project(...)`, `create_feature(...)`, `set_spec(...)`, `set_plan(...)`, `set_tasks(...)`, `update_task(code, …)`, `update_entity(kind, code, fields)`, `add_task_dependency(...)`, `delete_entity(...)`.

**Export tools** (on-demand markdown view, NEVER the source of truth): `export_feature_to_md(feature, output_dir)`, `export_project_to_md(project, output_path?)`.

### Rules — non-negotiable

1. **Read the DB before doing anything.** Never assume what a feature contains; always call `get_feature(...)` first. Never assume what the constitution says; always call `get_constitution(project='bill-splitter')` first.
2. **Every write goes through an MCP tool.** Never edit `.db` directly. Never edit a generated `.md` file expecting the DB to follow — the DB doesn't watch the filesystem.
3. **No markdown spec exists.** If you find yourself looking for `spec.md`, `plan.md`, `tasks.md`, `research.md`, `data-model.md`, `quickstart.md`, or `contracts/*.md`, **stop** — those files do not exist in this project and finding any such file means it's stale leftover, not the spec. The spec is the DB.
4. **Schema awareness before writes.** Before any `set_spec`/`set_plan`/`set_tasks`/`update_entity` call, consult `specs-db://schema` (or call `describe_schema(table)`) to confirm field names, enum values, and required columns. Passing an unknown field or a non-enum status value will be rejected by a CHECK constraint.
5. **Clarifications resolve BEFORE the DB write, not after.** There is no "NEEDS CLARIFICATION" marker in any row. If a piece of info is missing, you `AskUserQuestion` until you have the answer, then write. See Principle IV below.

## Spec-driven workflow (the 4 slash commands)

Each command is a thin layer over the MCP tools. Every command writes to the DB; none write `.md` files.

1. **`/specify <description>`** — capture a new feature.
   - `list_features()` → pick next `sequence_number`.
   - `create_feature(...)` → empty `feature` row.
   - `AskUserQuestion` rounds to gather user_stories, FRs, edge_cases, SCs, assumptions, key_entities.
   - `set_spec(...)` → all spec rows in one batched call.
   - `set_plan(checklists=[{slug:'requirements', ...}])` → the spec-quality checklist.

2. **`/plan`** — derive the implementation plan.
   - `get_feature(slug, sections=['spec'])` + `get_constitution(project='bill-splitter')` for context.
   - `AskUserQuestion` rounds for each plan section the user hasn't already stated.
   - `set_plan(summary=..., technical_context=..., project_structure=..., research=..., data_model=..., quickstart=..., api_endpoints=[...], checklists=[...])`.
   - `update_entity(kind='feature', code_or_id=<slug>, fields={'status': 'planned'})`.

3. **`/tasks`** — break the plan into tasks.
   - `get_feature(slug)` to pull spec + plan + contracts.
   - `set_tasks(phases=[...], tasks=[...], dependencies=[...])`.
   - `next_tasks(feature)` to sanity-check that Setup has at least one ready-to-start task.

4. **`/implement`** — execute the work.
   - `list_features()` → pick `planned` feature.
   - `get_feature(slug)` + `get_constitution(project)` for context.
   - Loop: `next_tasks(feature)` → mark task `in_progress` via `update_task(code, status='in_progress')` → write code → tests pass → `update_task(code, status='done')`.
   - At the end: `update_entity(kind='feature', code_or_id=<slug>, fields={'status': 'done'})`.

## Principle IV: Ask, Don't Assume

The constitution (read it from the DB via `get_constitution`) names this as a **NON-NEGOTIABLE** principle. Concretely:

- Every line that lands in the DB must trace to something the user explicitly said. If a gap exists, STOP and `AskUserQuestion` (grouped, ≤4 at a time, batched but never deferred).
- Spec-kit's "make informed guesses based on industry standards" and "max 3 [NEEDS CLARIFICATION] markers" defaults **do NOT apply** here. There is no marker cap; there are no markers at all — clarifications are resolved synchronously via `AskUserQuestion` before the row is written.
- If the user explicitly says "use your judgment" / "you decide", record the deferral as an `assumption` row (e.g., `"User deferred to AI judgment for X (2026-05-20)"`). Silent guesses are forbidden.


## Constitution (snapshot — DB is source of truth)

> The canonical version of these principles lives in the specs DB (`constitution_principle` rows + `project.constitution_body`). The snapshot below is regenerated from there by the `/read-constitution` skill. **If this section drifts from the DB, trust the DB** and re-sync.

<!-- CONSTITUTION START -->
_Constitution v2.0.0 — snapshot from the specs DB (canonical source). Last synced from DB: 2026-05-20. **If this drifts from the DB, trust the DB** and re-run `/read-constitution`._

### Core Principles

#### I. Spec-Driven Development (NON-NEGOTIABLE)

Every code change traces to a written specification before implementation begins. A specification captures intent: who the user is, what capability they want, why it matters, and what "done" looks like expressed as observable acceptance criteria. No code reaches `main` without a corresponding spec — bug fixes included; the bug itself becomes a one-paragraph spec.

Intent is the user's. The AI's job is to structure it into testable AC, never to invent scope. When the intent is ambiguous, the AI must STOP and ASK — it must never default-fill from convention, common patterns, or assumptions about what most apps do.

#### II. Test-First Discipline (NON-NEGOTIABLE)

TDD is mandatory for every `[behavioral]` acceptance criterion. Order is fixed: write the AC → write a failing test named `FR-NNN: <description>` where `FR-NNN` is the `functional_requirement.code` from the DB → confirm the test fails for the right reason (missing implementation, NOT syntax / import / dependency error) → implement until green → refactor with the suite green. Multiple tests can share the same FR prefix when they verify different aspects of the same requirement.

Tests are the executable form of the spec. They are NEVER modified to make them pass. If a test seems wrong, the SPEC is wrong, and the spec must be amended first (with rationale recorded in Verification notes). Visual AC are exempt from unit tests; they are verified by screenshot-based judgment via `ui-verifier`.

#### III. Mobile-First on Both Platforms

Bill Split is a Flutter mobile app targeting iOS 13+ and Android API 23+. Every feature must work on both platforms; iOS-only or Android-only features require explicit justification in the spec's Context. Visual AC are checked against the iPhone 17 simulator AND the Medium_Phone Android emulator via `mobile-mcp` screenshots. Cupertino/Material divergence is acceptable when it makes the platform feel native; gratuitous divergence is not.

#### IV. Ask, Don't Assume (NON-NEGOTIABLE)

Across drafting, implementation, and verification, every line of every artifact must trace to something the user explicitly wrote, said, or answered when asked. The moment any participant senses a gap — a missing piece of intent, an ambiguous statement, a detail the source does not cover, an architectural decision the spec does not specify — they stop and ask the user. They do not pre-fill answers, even with sensible-sounding defaults. "Use your judgment" / "you decide" is an explicit deferral and must be recorded in the spec's Context section; silent decisions are forbidden.

### Other Constitutional Sections


### Technology Constraints

The Bill Split app serves the Egyptian restaurant market (and is locale-overridable for elsewhere). The app is split into two tiers — a Flutter frontend that ships to user devices and a stateless Python backend that holds the Gemini API key. Both stacks below are locked unless an amendment to this constitution explicitly removes or replaces an entry.

#### Frontend stack (Flutter)

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

#### Backend stack (Python, added 2026-05-19, constitution v1.1.0)

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

#### Non-negotiable security rules

- **The `GEMINI_API_KEY` MUST NEVER ship inside the Flutter app build.** It is set only in the backend's runtime environment (Cloud Run env var, or a deploy-time secret manager). The Flutter app NEVER reads it; no Flutter `.env` file references it.
- **Every app → backend request MUST carry a Firebase Anonymous Auth ID token in the `Authorization: Bearer <token>` header.** The backend MUST verify the token using `firebase-admin` before invoking Gemini. Unauthenticated requests return `401`.
- **The backend MUST NOT be deployed publicly without auth.** The 401-on-missing-token gate is the only thing preventing arbitrary callers from burning the Gemini quota.

### Development Workflow & Quality Gates

Every change passes through the same gates. The custom skill suite (`spec-author`, `implement-tests`, `implement-feature`, `implement-story`, `verifier`, `ui-verifier`) and the spec-kit equivalents BOTH operate against these gates — whichever drives the change, the gates are identical:

1. A spec exists for the change (story file under `specs/features/<feature>/STORY-NNN-*.md` in the custom system, or the spec-kit `specs/<feature>/spec.md` equivalent during the migration).
2. For each `[behavioral]` AC, a failing test exists named `FR-NNN: <description>` (where `FR-NNN` is the `functional_requirement.code` from the DB) and demonstrably fails for the right reason before any implementation is written.
3. Implementation makes the AC tests pass WITHOUT modifying the tests.
4. `flutter test` (full suite) is green — including pre-existing tests. No regressions allowed.
5. `flutter analyze` reports zero errors. No `// ignore:` suppressions, no `dynamic` to dodge type errors.
6. For specs with any `[visual]` AC: `ui-verifier` has reviewed and either passed or returned with notes that the implementer must address before re-submitting.
7. The `verifier` sub-agent has reviewed all `[behavioral]` AC and flipped Status to `done`.

Bug fixes that cross multiple specs do NOT require a new spec, but the verifier re-checks affected `done` specs after the fix and flags any regression as blocking.

Pre-commit (when configured): the full test suite passes and `scripts/spec/regen-index --check` validates the spec index.

### Governance

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

**Version**: 2.0.0 | **Ratified**: 2026-05-19 | **Last Amended**: 2026-05-20
<!-- CONSTITUTION END -->

## Implementation conventions (for the rebuild)

The Flutter + FastAPI scaffold was deleted in commit `9ff6957` and will be rebuilt from the DB. These conventions are guardrails for that rebuild — they're not separate sources of truth, just consistent defaults:

- **Frontend**: Flutter stable, Dart 3.x. Target iOS 13+ and Android API 23+. Material 3 with `ColorScheme.fromSeed(seedColor: 0xFF1976D2)` (royal blue), surface override `0xFFFAF8F4` (warm off-white). Routing via `go_router`. HTTP via `dio`.
- **Backend**: Python 3.12+, FastAPI, uvicorn, pytest. Stateless — no DB on the backend side. Deployed to Cloud Run free tier.
- **Egypt locale defaults**: EGP currency, 12% service charge, 14% VAT — overridable per bill.
- **Test naming**: `FR-NNN: <description>` where `FR-NNN` is a `functional_requirement.code` from the DB.
- **Non-negotiable security rules** (from `constitution_principle` rows — verify by reading them):
  - `GEMINI_API_KEY` lives ONLY in the backend environment; NEVER in the Flutter app build.
  - Every app → backend request carries a Firebase Anonymous Auth ID token, verified server-side via `firebase-admin`.

When the implementation tasks land via `/speckit-implement`, the file paths the tasks reference become the new `frontend/` and `backend/` directories.

<!-- SPECKIT START -->
**Active feature**: `001-bill-split-flow` — once the DB is repopulated, fetch its full state with:

```
mcp__specs-mcp__get_feature(feature='001-bill-split-flow')
```

That single call returns the feature row, every user story (with acceptance scenarios nested), every FR/edge case/SC/assumption/key entity, the plan blob columns, every API endpoint, every phase/task/dependency, and every checklist. **It is your authoritative read for everything about this feature.** Do not look for sibling `.md` files — there are none.
<!-- SPECKIT END -->
