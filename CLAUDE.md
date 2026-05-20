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

1. **`/speckit-specify <description>`** — capture a new feature.
   - `list_features()` → pick next `sequence_number`.
   - `create_feature(...)` → empty `feature` row.
   - `AskUserQuestion` rounds to gather user_stories, FRs, edge_cases, SCs, assumptions, key_entities.
   - `set_spec(...)` → all spec rows in one batched call.
   - `set_plan(checklists=[{slug:'requirements', ...}])` → the spec-quality checklist.

2. **`/speckit-plan`** — derive the implementation plan.
   - `get_feature(slug, sections=['spec'])` + `get_constitution(project='bill-splitter')` for context.
   - `AskUserQuestion` rounds for each plan section the user hasn't already stated.
   - `set_plan(summary=..., technical_context=..., project_structure=..., research=..., data_model=..., quickstart=..., api_endpoints=[...], checklists=[...])`.
   - `update_entity(kind='feature', code_or_id=<slug>, fields={'status': 'planned'})`.

3. **`/speckit-tasks`** — break the plan into tasks.
   - `get_feature(slug)` to pull spec + plan + contracts.
   - `set_tasks(phases=[...], tasks=[...], dependencies=[...])`.
   - `next_tasks(feature)` to sanity-check that Setup has at least one ready-to-start task.

4. **`/speckit-implement`** — execute the work.
   - `list_features()` → pick `planned` feature.
   - `get_feature(slug)` + `get_constitution(project)` for context.
   - Loop: `next_tasks(feature)` → mark task `in_progress` via `update_task(code, status='in_progress')` → write code → tests pass → `update_task(code, status='done')`.
   - At the end: `update_entity(kind='feature', code_or_id=<slug>, fields={'status': 'done'})`.

## Principle IV: Ask, Don't Assume

The constitution (read it from the DB via `get_constitution`) names this as a **NON-NEGOTIABLE** principle. Concretely:

- Every line that lands in the DB must trace to something the user explicitly said. If a gap exists, STOP and `AskUserQuestion` (grouped, ≤4 at a time, batched but never deferred).
- Spec-kit's "make informed guesses based on industry standards" and "max 3 [NEEDS CLARIFICATION] markers" defaults **do NOT apply** here. There is no marker cap; there are no markers at all — clarifications are resolved synchronously via `AskUserQuestion` before the row is written.
- If the user explicitly says "use your judgment" / "you decide", record the deferral as an `assumption` row (e.g., `"User deferred to AI judgment for X (2026-05-20)"`). Silent guesses are forbidden.

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
