---
name: "speckit-tasks"
description: "Generate an actionable, dependency-ordered tasks.md for the feature based on available design artifacts."
argument-hint: "Optional task generation constraints"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "github-spec-kit"
  source: "templates/commands/tasks.md"
user-invocable: true
disable-model-invocation: false
---


## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Pre-Execution Checks

**Check for extension hooks (before tasks generation)**:
- Check if `.specify/extensions.yml` exists in the project root.
- If it exists, read it and look for entries under the `hooks.before_tasks` key
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

> **Storage model (this project): DB-first.** Phase/task content is written to the `specs.db` database via the **`specs-mcp`** MCP server. No `tasks.md` file is produced — phases become `phase` rows, tasks become `task` rows, and edges become `task_dependency` rows.
>
> **Prerequisite tools (on `specs-mcp`):** `get_feature`, `set_tasks`, `list_tasks`, `update_entity`, `describe_schema`.
>
> **Schema reference:** consult the resource `specs-db://schema` for `phase`, `task`, `task_dependency` field shapes (especially status enums and the `[P]` parallelizable flag).

1. **Identify the active feature**:
   - If `$ARGUMENTS` contains a slug, use it.
   - Otherwise call `mcp__specs-mcp__list_features()` and pick the most recently `planned` feature. If ambiguous, ask via `AskUserQuestion`.

2. **Load all design context** from the DB:
   - `mcp__specs-mcp__get_feature(feature=<slug>)` — returns the feature + user_stories + acceptance_scenarios + edge_cases + FRs + SCs + assumptions + key_entities + plan blobs + api_endpoints + existing tasks (if any).
   - From the response, extract:
     - User stories with priorities (P1, P2, ...) → drive the phase structure
     - FRs → drive task content
     - `plan.technical_context` + `plan.project_structure` → tech stack and file layout
     - `plan.data_model` → entities and validation rules
     - `api_endpoint` rows → contract test tasks
     - `plan.research` → setup tasks
     - `plan.quickstart` → smoke-test tasks
   - If the feature has no `plan` row yet (`get_feature` returns `plan=null`), STOP and tell the user to run `/speckit-plan` first.

3. **Build the phase + task graph**:
   - Phase 1 → Setup (project init, infrastructure scaffolding)
   - Phase 2 → Foundational (blocking prerequisites — types, theme, routing, auth skeleton)
   - Phase 3+ → One phase per user story in priority order (P1 → Phase 3, P2 → Phase 4, ...). Set the phase's `user_story_ordinal` so the schema can join phase→story.
   - Final phase → Polish & cross-cutting concerns
   - For each task, decide: `code` (T001, T002, ...), `description` (must include the file path), `parallelizable` (no in-phase blockers), `notes` (optional rationale), `phase_ordinal`.
   - For each task→task dependency that's not implied by phase order, add an entry to the `dependencies` array (e.g., `{task: 'T029', depends_on: 'T022'}`).

4. **Write the tasks** in one call:
   ```
   mcp__specs-mcp__set_tasks(
     feature='<slug>',
     phases=[
       {ordinal: 1, name: 'Setup', purpose: '...', user_story_ordinal: null},
       {ordinal: 2, name: 'Foundational', purpose: '...', user_story_ordinal: null},
       {ordinal: 3, name: 'US1', purpose: '...', user_story_ordinal: 1},
       {ordinal: 4, name: 'US2', purpose: '...', user_story_ordinal: 2},
       ...
       {ordinal: <N>, name: 'Polish', purpose: '...', user_story_ordinal: null},
     ],
     tasks=[
       {code: 'T001', description: 'Create project structure per implementation plan',
        phase_ordinal: 1, parallelizable: false, status: 'pending'},
       {code: 'T002', description: '[P] Initialize backend skeleton at backend/app/',
        phase_ordinal: 1, parallelizable: true, status: 'pending'},
       {code: 'T012', description: '[P] [US1] Create Bill model in frontend/lib/state/bill_state.dart',
        phase_ordinal: 3, parallelizable: true, status: 'pending'},
       ...
     ],
     dependencies=[
       {task: 'T029', depends_on: 'T022'},
       {task: 'T030', depends_on: 'T013'},
       {task: 'T030', depends_on: 'T014'},
       ...
     ]
   )
   ```

5. **Validate the graph**:
   - Run `mcp__specs-mcp__next_tasks(feature=<slug>)` — should return the Setup tasks (the only ones with no deps). If it returns nothing, there's a cycle or an isolation issue; fix it.
   - Run `mcp__specs-mcp__list_tasks(feature=<slug>, status='pending')` and count tasks per phase. Confirm every user_story has at least one task in its phase.

6. **Report**:
   - Counts: `phases`, `tasks`, `dependencies`.
   - Tasks per user story (e.g., "US1: 12 tasks, US2: 3 tasks").
   - Parallel opportunities (tasks with `parallelizable=true`).
   - MVP suggestion (typically through end of US1's phase).
   - Suggested next command: `/speckit-implement`.

6. **Check for extension hooks**: After tasks.md is generated, check if `.specify/extensions.yml` exists in the project root.
   - If it exists, read it and look for entries under the `hooks.after_tasks` key
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

Context for task generation: $ARGUMENTS

Every task must be specific enough that an LLM can complete it without additional context. File paths belong in `task.description` (the DB schema doesn't have a separate file column — the path is part of the description text).

## Task Generation Rules

**CRITICAL**: Tasks MUST be organized by user story (via `phase.user_story_ordinal`) to enable independent implementation and testing.

**Tests are OPTIONAL**: Only generate test tasks if explicitly requested in the feature specification or if user requests TDD approach. (Note: the Bill Splitter constitution Principle II makes TDD mandatory — so for this project, tests ARE required.)

### Task Row Shape

Each `task` row passed to `set_tasks` MUST carry:

| field | rules |
|---|---|
| `code` | `T001`, `T002`, ... — sequential, zero-padded to 3 digits. Unique per feature. |
| `description` | Clear action **with exact file path embedded**. Story label prefix `[US1]` etc. is OPTIONAL since the phase already carries `user_story_ordinal`; the convention is to include it for readability. |
| `phase_ordinal` | Maps the task to its phase (1=Setup, 2=Foundational, 3+=user-story phases, final=Polish). |
| `parallelizable` | `true` if task has no in-phase blockers (different files, doesn't read in-progress output). `false` otherwise. |
| `status` | `'pending'` for new tasks (the schema default; safe to omit). |
| `notes` | Optional. Trailing rationale ("**N/A**: ..." / "rejected by user ..."). |

**Examples of good descriptions**:

- `T001`: `Create project structure per implementation plan`
- `T005`: `Implement authentication middleware in src/middleware/auth.py` (with `parallelizable=true`)
- `T012`: `[US1] Create User model in src/models/user.py` (with `parallelizable=true`)
- `T014`: `[US1] Implement UserService in src/services/user_service.py`

### Task Organization

1. **From User Stories** (read via `get_feature(...)['user_stories']`) — PRIMARY ORGANIZATION:
   - Each user story (P1, P2, P3...) gets its own phase, linked via `phase.user_story_ordinal`.
   - Map all related components to their story:
     - Models / state for that story
     - Services for that story
     - UI screens / widgets for that story
     - Tests specific to that story (constitution mandates them)
   - Most stories should be independent; record real cross-story dependencies in the `dependencies` array.

2. **From API endpoints** (read via `get_feature(...)['api_endpoints']`):
   - Each endpoint → contract test task (per Principle II) before the implementation task, in the relevant story's phase.

3. **From `plan.data_model`** (read via `get_feature(...)['plan']['data_model']`):
   - Each entity → a "create model" task in the story phase that first needs it.
   - If an entity serves multiple stories, hoist its creation into Setup or Foundational.
   - Validation rules → service-layer tasks in the appropriate story phase.

4. **From Setup / Infrastructure** (read via `plan.technical_context`, `plan.project_structure`):
   - Shared infrastructure → Setup phase (Phase 1).
   - Foundational/blocking tasks (theme, routing, auth skeleton, type definitions) → Foundational phase (Phase 2).
   - Story-specific setup → within that story's phase.

### Phase Structure

- **Phase 1**: Setup (project initialization)
- **Phase 2**: Foundational (blocking prerequisites - MUST complete before user stories)
- **Phase 3+**: User Stories in priority order (P1, P2, P3...)
  - Within each story: Tests (if requested) → Models → Services → Endpoints → Integration
  - Each phase should be a complete, independently testable increment
- **Final Phase**: Polish & Cross-Cutting Concerns
