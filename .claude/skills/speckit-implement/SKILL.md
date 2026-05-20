---
name: "speckit-implement"
description: "Execute the implementation plan by processing and executing all tasks defined in tasks.md"
argument-hint: "Optional implementation guidance or task filter"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "github-spec-kit"
  source: "templates/commands/implement.md"
user-invocable: true
disable-model-invocation: false
---


## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Pre-Execution Checks

**Check for extension hooks (before implementation)**:
- Check if `.specify/extensions.yml` exists in the project root.
- If it exists, read it and look for entries under the `hooks.before_implement` key
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

> **Storage model (this project): DB-first.** Tasks live in the `specs.db` database, not in `tasks.md`. The agent reads tasks via the `specs-mcp` MCP server, executes the actual code changes in the filesystem, then marks each task `done` via `update_task`.
>
> **Prerequisite tools (on `specs-mcp`):** `get_feature`, `list_tasks`, `next_tasks`, `get_task`, `update_task`, `get_constitution`.

1. **Identify the active feature**:
   - If `$ARGUMENTS` contains a slug, use it.
   - Otherwise call `mcp__specs-mcp__list_features()` and pick the most recently `planned`/`in_progress` feature. If ambiguous, ask via `AskUserQuestion`.
   - Fail fast if the feature has no tasks yet (`list_tasks` returns empty): tell the user to run `/speckit-tasks` first.

2. **Check checklist status** (from the `checklist` rows on the feature):
   - Call `mcp__specs-mcp__get_feature(feature=<slug>, sections=['checklists'])`.
   - For each checklist row, parse `items` (markdown) and count `- [ ]` (incomplete) vs `- [x]`/`- [X]` (complete).
   - Build a status table:

     ```text
     | Checklist        | Total | Completed | Incomplete | Status |
     |------------------|-------|-----------|------------|--------|
     | requirements     | 12    | 12        | 0          | ✓ PASS |
     | ux               | 8     |  5        | 3          | ✗ FAIL |
     ```

   - **PASS**: all checklists complete → proceed automatically.
   - **FAIL**: any checklist has incomplete items → STOP and ask the user via `AskUserQuestion` whether to proceed anyway. Halt if no.

3. **Load implementation context** from the DB (single `get_feature` call):
   ```
   mcp__specs-mcp__get_feature(feature='<slug>')   # returns spec + plan + contracts + tasks + checklists
   ```
   Plus the constitution:
   ```
   mcp__specs-mcp__get_constitution(project='<project_slug>')
   ```
   Extract:
   - **Tasks** (`response['tasks']`, `response['phases']`, `response['task_dependencies']`) — the execution plan.
   - **Plan blobs** (`response['plan']['technical_context']`, `['project_structure']`, `['data_model']`, `['quickstart']`) — tech stack, file layout, entities, smoke tests.
   - **API endpoints** (`response['api_endpoints']`) — contracts the implementation must match.
   - **FRs / user stories / ACs / edge cases** — the behavioral target.
   - **Constitution principles** — non-negotiable rules.

4. **Project Setup Verification**:
   - **REQUIRED**: Create/verify ignore files based on actual project setup:

   **Detection & Creation Logic**:
   - Check if the following command succeeds to determine if the repository is a git repo (create/verify .gitignore if so):

     ```sh
     git rev-parse --git-dir 2>/dev/null
     ```

   - Check if Dockerfile* exists or Docker in plan.md → create/verify .dockerignore
   - Check if .eslintrc* exists → create/verify .eslintignore
   - Check if eslint.config.* exists → ensure the config's `ignores` entries cover required patterns
   - Check if .prettierrc* exists → create/verify .prettierignore
   - Check if .npmrc or package.json exists → create/verify .npmignore (if publishing)
   - Check if terraform files (*.tf) exist → create/verify .terraformignore
   - Check if .helmignore needed (helm charts present) → create/verify .helmignore

   **If ignore file already exists**: Verify it contains essential patterns, append missing critical patterns only
   **If ignore file missing**: Create with full pattern set for detected technology

   **Common Patterns by Technology** (from plan.md tech stack):
   - **Node.js/JavaScript/TypeScript**: `node_modules/`, `dist/`, `build/`, `*.log`, `.env*`
   - **Python**: `__pycache__/`, `*.pyc`, `.venv/`, `venv/`, `dist/`, `*.egg-info/`
   - **Java**: `target/`, `*.class`, `*.jar`, `.gradle/`, `build/`
   - **C#/.NET**: `bin/`, `obj/`, `*.user`, `*.suo`, `packages/`
   - **Go**: `*.exe`, `*.test`, `vendor/`, `*.out`
   - **Ruby**: `.bundle/`, `log/`, `tmp/`, `*.gem`, `vendor/bundle/`
   - **PHP**: `vendor/`, `*.log`, `*.cache`, `*.env`
   - **Rust**: `target/`, `debug/`, `release/`, `*.rs.bk`, `*.rlib`, `*.prof*`, `.idea/`, `*.log`, `.env*`
   - **Kotlin**: `build/`, `out/`, `.gradle/`, `.idea/`, `*.class`, `*.jar`, `*.iml`, `*.log`, `.env*`
   - **C++**: `build/`, `bin/`, `obj/`, `out/`, `*.o`, `*.so`, `*.a`, `*.exe`, `*.dll`, `.idea/`, `*.log`, `.env*`
   - **C**: `build/`, `bin/`, `obj/`, `out/`, `*.o`, `*.a`, `*.so`, `*.exe`, `*.dll`, `autom4te.cache/`, `config.status`, `config.log`, `.idea/`, `*.log`, `.env*`
   - **Swift**: `.build/`, `DerivedData/`, `*.swiftpm/`, `Packages/`
   - **R**: `.Rproj.user/`, `.Rhistory`, `.RData`, `.Ruserdata`, `*.Rproj`, `packrat/`, `renv/`
   - **Universal**: `.DS_Store`, `Thumbs.db`, `*.tmp`, `*.swp`, `.vscode/`, `.idea/`

   **Tool-Specific Patterns**:
   - **Docker**: `node_modules/`, `.git/`, `Dockerfile*`, `.dockerignore`, `*.log*`, `.env*`, `coverage/`
   - **ESLint**: `node_modules/`, `dist/`, `build/`, `coverage/`, `*.min.js`
   - **Prettier**: `node_modules/`, `dist/`, `build/`, `coverage/`, `package-lock.json`, `yarn.lock`, `pnpm-lock.yaml`
   - **Terraform**: `.terraform/`, `*.tfstate*`, `*.tfvars`, `.terraform.lock.hcl`
   - **Kubernetes/k8s**: `*.secret.yaml`, `secrets/`, `.kube/`, `kubeconfig*`, `*.key`, `*.crt`

5. **Mark the feature in-progress** (so cross-cutting reports reflect it):
   ```
   mcp__specs-mcp__update_entity(kind='feature', code_or_id='<slug>',
                                  fields={'status': 'in_progress'})
   ```

6. **Pull the work queue** in dependency order. The MCP knows the dependency edges:
   ```
   mcp__specs-mcp__next_tasks(feature='<slug>', limit=50)   # ready-to-start
   mcp__specs-mcp__list_tasks(feature='<slug>', status='pending')   # everything left
   ```
   `next_tasks` returns only tasks whose `task_dependency` edges all point to `done` tasks. Use this as the iteration unit.

7. **Execute implementation** following the task plan:
   - **Phase-by-phase**: complete each phase before moving to the next. Phases are read from `response['phases']`; tasks carry `phase_id`.
   - **Respect dependencies**: only work on tasks returned by `next_tasks`. As each task completes, more become eligible.
   - **TDD**: tests first (Constitution Principle II is non-negotiable). The task graph should already encode test-before-impl ordering — if you find an impl task without a preceding test task, STOP and ask the user.
   - **File-based coordination**: tasks touching the same file paths must run sequentially. The `parallelizable` flag from the task row is a hint; verify by inspecting the file paths in `description`.
   - **Mark `in_progress`** when you start a task:
     ```
     mcp__specs-mcp__update_task(code='T037', status='in_progress')
     ```
   - **Mark `done`** when finished:
     ```
     mcp__specs-mcp__update_task(code='T037', status='done',
                                  notes='<optional addendum>')
     ```
     `update_task` auto-sets `completed_at` when status flips to `done`.

8. **Implementation execution rules**:
   - **Setup first**: initialize project structure, dependencies, configuration.
   - **Tests before code**: write failing tests for ACs, FRs, contracts, then implement until green.
   - **Core development**: models, services, screens/endpoints per the task descriptions.
   - **Integration work**: backend wiring, auth, logging, external services.
   - **Polish and validation**: regression tests, performance, docs.

9. **Progress tracking and error handling**:
   - Report progress after each completed task (the agent's text output; the DB also records `completed_at`).
   - Halt execution if any non-parallel task fails — and leave the task `in_progress` (or set to `skipped` if abandoning) so resumption is clean.
   - For parallel tasks, continue with successful ones, mark failures explicitly via `update_task(status='skipped', notes='reason')`.
   - Provide clear error messages with context.

10. **Completion validation**:
    - Run `mcp__specs-mcp__list_tasks(feature='<slug>', status='pending')` — should be empty.
    - Verify implemented features match the spec by spot-checking FRs against code (use `mcp__specs-mcp__search('<fr-code>')` to find the relevant task/code).
    - Tests pass and coverage meets the constitution's requirements.
    - Mark the feature `done`:
      ```
      mcp__specs-mcp__update_entity(kind='feature', code_or_id='<slug>',
                                     fields={'status': 'done'})
      ```
    - Report final summary: tasks done / skipped / superseded, plus duration.

Note: This command assumes a complete task graph exists in the DB. If `list_tasks` returns empty, run `/speckit-tasks` first.

10. **Check for extension hooks**: After completion validation, check if `.specify/extensions.yml` exists in the project root.
    - If it exists, read it and look for entries under the `hooks.after_implement` key
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
