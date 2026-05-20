---
name: "speckit-plan"
description: "Execute the implementation planning workflow using the plan template to generate design artifacts."
argument-hint: "Optional guidance for the planning phase"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "github-spec-kit"
  source: "templates/commands/plan.md"
user-invocable: true
disable-model-invocation: false
---


## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Pre-Execution Checks

**Check for extension hooks (before planning)**:
- Check if `.specify/extensions.yml` exists in the project root.
- If it exists, read it and look for entries under the `hooks.before_plan` key
- If the YAML cannot be parsed or is invalid, skip hook checking silently and continue normally
- Filter out hooks where `enabled` is explicitly `false`. Treat hooks without an `enabled` field as enabled by default.
- For each remaining hook, do **not** attempt to interpret or evaluate hook `condition` expressions:
  - If the hook has no `condition` field, or it is null/empty, treat the hook as executable
  - If the hook defines a non-empty `condition`, skip the hook and leave condition evaluation to the HookExecutor implementation
- When constructing slash commands from hook command names, replace dots (`.`) with hyphens (`-`). For example, `speckit.git.commit` → `/speckit-git-commit`.
- For each executable hook, output the following based on its `optional` flag:
  - **Optional hook** (`optional: true`):
    ```
    ## Extension Hooks

    **Optional Pre-Hook**: {extension}
    Command: `/{command}`
    Description: {description}

    Prompt: {prompt}
    To execute: `/{command}`
    ```
  - **Mandatory hook** (`optional: false`):
    ```
    ## Extension Hooks

    **Automatic Pre-Hook**: {extension}
    Executing: `/{command}`
    EXECUTE_COMMAND: {command}

    Wait for the result of the hook command before proceeding to the Outline.
    ```
- If no hooks are registered or `.specify/extensions.yml` does not exist, skip silently

## Outline

> **Storage model (this project): DB-first.** Plan content is written to the `specs.db` database via the **`specs-mcp`** MCP server. No `plan.md`, `research.md`, `data-model.md`, `quickstart.md`, or `contracts/*.md` file is produced — they all become blob columns on the `plan` row (and rows in `api_endpoint`).
>
> **Prerequisite tools (on `specs-mcp`):** `get_feature`, `set_plan`, `update_entity`, `get_constitution`, `describe_schema`.
>
> **Schema reference:** consult the resource `specs-db://schema` for exact field shapes on `plan`, `api_endpoint`, and `checklist`.

1. **Identify the active feature**:
   - If `$ARGUMENTS` contains a slug (e.g. `001-bill-split-flow`), use it.
   - Otherwise call `mcp__specs-mcp__list_features()` and pick the most recently created `draft`/`planned` feature. If ambiguous, ask via `AskUserQuestion`.

2. **Load context**:
   - `mcp__specs-mcp__get_feature(feature=<slug>, sections=['spec'])` — pulls the spec content the plan will reference.
   - `mcp__specs-mcp__get_constitution(project=<project_slug>)` — pulls the constitution body + every principle. The constitution is the project's law; treat its rules as **non-negotiable** when planning.

3. **Fill the plan content** by asking the user (`AskUserQuestion`, grouped, ≤4 at a time) for every section. Constitution Principle IV forbids silent defaults. Use as many questions as needed.

   The `plan` row has these markdown-blob columns (all optional, all flat text — section headers go INSIDE the blob, no nested tables):

   | column | spec-kit equivalent | what goes here |
   |---|---|---|
   | `summary` | plan.md > Summary | 1-paragraph overview of the technical approach |
   | `technical_context` | plan.md > Technical Context | bulleted Language/Version, Primary Dependencies, Storage, Testing, Target Platform, Performance Goals, Constraints, Scale/Scope |
   | `project_structure` | plan.md > Project Structure | the directory tree(s) the implementation will create |
   | `research` | research.md (Phase 0) | numbered decisions (R-1, R-2, ...) with Decision / Rationale / Alternatives considered |
   | `data_model` | data-model.md (Phase 1) | entities, fields, validation rules, state transitions |
   | `quickstart` | quickstart.md (Phase 1) | how to run locally — prereqs, commands per tier |

   Sibling rows the plan also produces:
   - `api_endpoint` rows (one per HTTP endpoint the backend will expose) — fields per `specs-db://schema`.
   - `checklist` rows for any plan-phase quality checks.

4. **Run the Constitution Check** mentally:
   - For each principle returned by `get_constitution`, decide PASS / CONDITIONAL / FAIL and write a one-sentence note.
   - Include this evaluation as a section inside the `technical_context` or `summary` blob (since we dropped the structured `constitution_check` table). Format as a small markdown table.
   - If any FAIL, surface it to the user via `AskUserQuestion` before proceeding — Principle I (Spec-Driven Development) is non-negotiable, so the user must explicitly waive or change scope.

5. **Write the plan** in one call (only include fields the user actually answered; omit others — they stay NULL):
   ```
   mcp__specs-mcp__set_plan(
     feature='<slug>',
     summary='<markdown>',
     technical_context='<markdown>',
     project_structure='<markdown>',
     research='<markdown>',
     data_model='<markdown>',
     quickstart='<markdown>',
     api_endpoints=[
       {
         method: 'POST', path: '/v1/extract',
         description: '...', auth_required: true,
         request_spec: '<markdown>', success_spec: '<markdown>',
         error_mapping: '<markdown — HTTP status → error code table>'
       },
       ...
     ],
     checklists=[ {slug: '...', title: '...', purpose: '...', items: '<markdown>'} ]
   )
   ```

6. **Re-evaluate the constitution check** after the plan is in. If a decision in `research` or `data_model` changed the picture, update the embedded check via `mcp__specs-mcp__update_entity(kind='plan', code_or_id=<slug>, fields={'technical_context': '<updated markdown>'})`.

7. **Update the `feature.status`** to `'planned'` via `update_entity(kind='feature', code_or_id='<slug>', fields={'status': 'planned'})`.

8. **Stop and report**: Command ends after the plan is written. Report:
   - `feature_slug`
   - which `plan` columns were populated (summary, technical_context, ...)
   - count of `api_endpoint` rows
   - count of `checklist` rows
   - Constitution check summary (PASS/CONDITIONAL/FAIL per principle)
   - Readiness for `/speckit-tasks`

5. **Check for extension hooks**: After reporting, check if `.specify/extensions.yml` exists in the project root.
   - If it exists, read it and look for entries under the `hooks.after_plan` key
   - If the YAML cannot be parsed or is invalid, skip hook checking silently and continue normally
   - Filter out hooks where `enabled` is explicitly `false`. Treat hooks without an `enabled` field as enabled by default.
   - For each remaining hook, do **not** attempt to interpret or evaluate hook `condition` expressions:
     - If the hook has no `condition` field, or it is null/empty, treat the hook as executable
     - If the hook defines a non-empty `condition`, skip the hook and leave condition evaluation to the HookExecutor implementation
   - When constructing slash commands from hook command names, replace dots (`.`) with hyphens (`-`). For example, `speckit.git.commit` → `/speckit-git-commit`.
   - For each executable hook, output the following based on its `optional` flag:
     - **Optional hook** (`optional: true`):
       ```
       ## Extension Hooks

       **Optional Hook**: {extension}
       Command: `/{command}`
       Description: {description}

       Prompt: {prompt}
       To execute: `/{command}`
       ```
     - **Mandatory hook** (`optional: false`):
       ```
       ## Extension Hooks

       **Automatic Hook**: {extension}
       Executing: `/{command}`
       EXECUTE_COMMAND: {command}
       ```
   - If no hooks are registered or `.specify/extensions.yml` does not exist, skip silently

## Phases (logical, written into `plan` blob columns)

There are no separate `phase 0` / `phase 1` files anymore — all phase outputs become columns on the single `plan` row.

### Phase 0: Outline & Research → `plan.research`

1. **Identify unknowns** in the user's technical answers (collected via `AskUserQuestion` in step 3 of the Outline above): unfamiliar dependencies, integration patterns, runtime/deployment choices.
2. For each unknown, gather a decision by **asking the user explicitly** (Constitution Principle IV — no silent guessing). For technology choices, offer the user 2-3 options via `AskUserQuestion` with implications.
3. **Write the findings into `plan.research`** using the format:

   ```markdown
   ## R-1: <decision topic>

   - **Decision**: <what was chosen>
   - **Rationale**: <why; trace to a user answer + date>
   - **Alternatives considered**:
     - <name>: rejected because <reason>
     - <name>: rejected because <reason>
   ```

   Numbered `R-1`, `R-2`, … in the order the questions were asked. Quote the user's exact words in the rationale.

### Phase 1: Design & Contracts → `plan.data_model` + `api_endpoint` rows + `plan.quickstart`

1. **Extract entities** → `plan.data_model` blob:
   - Per entity (BillState, Person, Item, etc.): a small markdown table of fields with type + notes.
   - Validation rules section (traces each rule back to an FR-NNN).
   - State transitions section (per screen / per entity).

2. **Define HTTP contracts** (if backend exposes any) → one `api_endpoint` row per endpoint, via the `api_endpoints` array in `set_plan`:
   - `method`, `path`, `description`, `auth_required`.
   - `request_spec` and `success_spec` as markdown.
   - `error_mapping` as a markdown table of HTTP status → error code → cause.

3. **Quickstart** → `plan.quickstart` blob: prereqs, env vars, commands to run each tier locally, smoke-test invocations.

4. **Agent context update**: Update the plan reference between the `<!-- SPECKIT START -->` and `<!-- SPECKIT END -->` markers in `CLAUDE.md` to point to the active feature in the DB (e.g., `specs-db: feature slug '001-bill-split-flow'`). No file path is generated.

## Key rules

- The DB row is the source of truth. Don't produce `plan.md` / `research.md` / `data-model.md` / `quickstart.md` files. If a markdown export is needed for human review, call `mcp__specs-mcp__export_feature_to_md`.
- Refer to `specs-db://schema` for exact field shapes before each `set_plan` call.
- Every decision must trace to a user answer captured via `AskUserQuestion`. Silent defaults are forbidden.
- ERROR on gate failures or unresolved clarifications
