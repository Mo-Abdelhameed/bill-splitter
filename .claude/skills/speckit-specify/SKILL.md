---
name: "speckit-specify"
description: "Create or update the feature specification from a natural language feature description."
argument-hint: "Describe the feature you want to specify"
compatibility: "Requires spec-kit project structure with .specify/ directory"
metadata:
  author: "github-spec-kit"
  source: "templates/commands/specify.md"
user-invocable: true
disable-model-invocation: false
---


## User Input

```text
$ARGUMENTS
```

You **MUST** consider the user input before proceeding (if not empty).

## Pre-Execution Checks

**Check for extension hooks (before specification)**:
- Check if `.specify/extensions.yml` exists in the project root.
- If it exists, read it and look for entries under the `hooks.before_specify` key
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

The text the user typed after `/speckit-specify` in the triggering message **is** the feature description. Assume you always have it available in this conversation even if `$ARGUMENTS` appears literally below. Do not ask the user to repeat it unless they provided an empty command.

> **Storage model (this project): DB-first.** All spec content is written to the `specs.db` database via the **`specs-mcp`** MCP server. No `spec.md` file is produced. If you need a markdown export later, the user can call `mcp__specs-mcp__export_feature_to_md` or `export_project_to_md` explicitly.
>
> **Prerequisite tools (must exist on the `specs-mcp` server):** `list_features`, `create_feature`, `set_spec`, `set_plan`, `get_feature`, `update_entity`, `describe_schema`. Confirm by inspecting the tool list at session start.
>
> **Schema reference:** the resource `specs-db://schema` is auto-loaded; consult it for the exact field shapes of `user_story`, `acceptance_scenario`, `functional_requirement`, `edge_case`, `success_criterion`, `assumption`, `key_entity`, and `checklist`. The agent MUST NOT pass fields not declared there.

Given the feature description, do this:

1. **Generate a concise short name** (2-4 words) for the feature:
   - Analyze the feature description and extract the most meaningful keywords
   - Create a 2-4 word short name in kebab-case that captures the essence of the feature
   - Use action-noun format when possible (e.g., `user-auth`, `fix-payment-bug`)
   - Preserve technical terms and acronyms (OAuth2, API, JWT, etc.)
   - Examples:
     - "I want to add user authentication" → `user-auth`
     - "Implement OAuth2 integration for the API" → `oauth2-api-integration`
     - "Create a dashboard for analytics" → `analytics-dashboard`

2. **Branch creation** (optional, via hook):

   If a `before_specify` hook ran successfully in the Pre-Execution Checks above, it will have created/switched to a git branch and output JSON containing `BRANCH_NAME` and `FEATURE_NUM`. Note these values for reference, but they do **not** dictate the feature slug used in the DB.

   If the user explicitly provided `GIT_BRANCH_NAME`, pass it through to the hook so the branch script uses the exact value as the branch name.

3. **Resolve the project**:
   - Call `mcp__specs-mcp__list_features` (no args). Every returned row carries a `project_id` — they all share one for this repo. Note that id.
   - If `list_features` returns an empty list, the project hasn't been created yet. Ask the user via `AskUserQuestion` whether to bootstrap it now, and if yes, call `mcp__specs-mcp__create_project(slug=<project_slug>, name=<project_name>)` first.

4. **Pick the sequence number and feature slug**:
   - From the `list_features` result, take `max(sequence_number) + 1` (start at `1` if none exist). Zero-pad to 3 digits.
   - Construct the feature slug: `<NNN>-<short-name>` (e.g., `003-user-auth`).
   - If the user explicitly provided a slug or `SPECIFY_FEATURE_DIRECTORY`, honor it (parse the sequence number from the prefix).

5. **Gather the spec content** by interrogating the user — **DB writes happen in step 6, not yet**:

   For every piece of structured content the spec needs (title, user stories, acceptance scenarios, FRs, edge cases, key entities, success criteria, assumptions), if the user did **not** explicitly state it in their input or in linked source documents, STOP and ask via `AskUserQuestion` (grouped, ≤4 at a time). Constitution Principle IV (Ask, Don't Assume) **forbids** silent default-filling. Use as many `AskUserQuestion` calls as needed; do **not** cap at 3.

   Recommended question groupings:
   - **Title + scope**: human-readable feature title; in-scope vs explicitly-excluded.
   - **User stories**: who uses this; one story per major flow; priority (`P1`/`P2`/`P3`); `independent_test` criterion; `why_priority`.
   - **Acceptance scenarios per story**: Given/When/Then triples.
   - **Edge cases**: failure modes, empty/duplicate inputs, race conditions, optional `rationale` + `decided_at` when the resolution came from a user decision.
   - **Functional requirements**: `FR-001`, `FR-002`, … each a testable "The system MUST ..." sentence.
   - **Success criteria**: `SC-NNN` — measurable, technology-agnostic.
   - **Key entities**: domain nouns + descriptions.
   - **Assumptions**: explicit deferrals ("user said: use your judgment for X").

   If the user explicitly says "use your judgment" / "you decide", record the deferral as an `assumption` row in step 6.

6. **Create the feature row**:
   ```
   mcp__specs-mcp__create_feature(
     project=<project_slug>,
     slug='<NNN-short-name>',
     sequence_number=<N>,
     title='<title>',
     original_input='<the user input from $ARGUMENTS verbatim>'
   )
   ```
   Note the returned `feature_id` and `slug`.

7. **Write the spec content** in one call:
   ```
   mcp__specs-mcp__set_spec(
     feature='<NNN-short-name>',
     user_stories=[
       {
         ordinal: 1, title: '...', priority: 'P1',
         user_story_description: '...', why_priority: '...', independent_test: '...',
         acceptance_scenarios: [
           {ordinal: 1, given_text: '...', when_text: '...', then_text: '...'},
           ...
         ],
       },
       ...
     ],
     functional_requirements=[{code: 'FR-001', text: 'The app MUST ...'}, ...],
     edge_cases=[{ordinal: 1, scenario: '...', rationale: '...', decided_at: 'YYYY-MM-DD'}, ...],
     success_criteria=[{code: 'SC-001', text: '...'}, ...],
     assumptions=[{ordinal: 1, text: '...'}, ...],
     key_entities=[{name: 'Bill', description: '...'}, ...]
   )
   ```
   Refer to `specs-db://schema` for the exact field shapes if uncertain.

8. **Write the spec-quality checklist** (stored as a `checklist` row, scoped to this feature):
   ```
   mcp__specs-mcp__set_plan(
     feature='<NNN-short-name>',
     checklists=[{
       slug: 'requirements',
       title: 'Specification Quality Checklist',
       purpose: 'Validate specification completeness and quality before proceeding to planning',
       items: '<checklist body — see template below>'
     }]
   )
   ```
   Checklist body template (markdown; `[ ]` / `[x]` toggles per item):
   ```markdown
   ## Content Quality

   - [ ] No implementation details (languages, frameworks, APIs)
   - [ ] Focused on user value and business needs
   - [ ] Written for non-technical stakeholders
   - [ ] All mandatory sections completed

   ## Requirement Completeness

   - [ ] Requirements are testable and unambiguous
   - [ ] Success criteria are measurable
   - [ ] Success criteria are technology-agnostic (no implementation details)
   - [ ] All acceptance scenarios are defined
   - [ ] Edge cases are identified
   - [ ] Scope is clearly bounded
   - [ ] Dependencies and assumptions identified

   ## Feature Readiness

   - [ ] All functional requirements have clear acceptance criteria
   - [ ] User scenarios cover primary flows
   - [ ] Feature meets measurable outcomes defined in Success Criteria
   - [ ] No implementation details leak into specification
   ```

9. **Self-validate**: Walk every item in the checklist mentally against what you just wrote to the DB.
   - For each item, decide pass/fail. Document specific issues (quote the entity you'd point at — `FR-002`, `US-1`, etc.).
   - If any fail, refine the affected rows via `mcp__specs-mcp__update_entity(kind=..., code_or_id=..., fields={...})` and re-check. **Max 3 iterations.** If still failing, leave the unchecked items in the checklist and warn the user in step 10.
   - There are NO `[NEEDS CLARIFICATION]` markers in the DB. All clarifications are resolved via `AskUserQuestion` before step 7 lands data.

10. **Report completion** to the user with:
    - `feature_id`: <db row id>
    - `slug`: `<NNN-short-name>`
    - `sequence_number`: <N>
    - Counts: user_stories, functional_requirements, edge_cases, success_criteria, assumptions, key_entities
    - Checklist pass/fail summary
    - Readiness for the next phase (`/speckit-plan`)

9. **Check for extension hooks**: After reporting completion, check if `.specify/extensions.yml` exists in the project root.
   - If it exists, read it and look for entries under the `hooks.after_specify` key
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

**NOTE:** Branch creation is handled by the `before_specify` hook (git extension). Spec directory and file creation are always handled by this core command.

## Quick Guidelines

- Focus on **WHAT** users need and **WHY**.
- Avoid HOW to implement (no tech stack, APIs, code structure).
- Written for business stakeholders, not developers.
- DO NOT create any checklists that are embedded in the spec. That will be a separate command.

### Section Requirements

- **Mandatory sections**: Must be completed for every feature
- **Optional sections**: Include only when relevant to the feature
- When a section doesn't apply, remove it entirely (don't leave as "N/A")

### For AI Generation

**Project override (Constitution Principle IV — Ask, Don't Assume):** spec-kit's defaults below ("make informed guesses", "max 3 markers", "examples of reasonable defaults") **DO NOT APPLY** in this project. Every detail must trace to the user's explicit input. When a gap exists, STOP and ask via `AskUserQuestion`. There is no marker cap; use as many `AskUserQuestion` calls as needed.

Concretely when drafting:

1. **No silent guessing**: never fill in scope, user types, security choices, performance targets, error behaviors, integration patterns, etc. from "industry standards". If the user didn't say it, ask.
2. **Document explicit deferrals**: if the user says "use your judgment" or "you decide", record that exact choice as an `assumption` row (e.g., `"User deferred to AI judgment for X (YYYY-MM-DD)"`).
3. **Think like a tester**: every requirement must be testable and unambiguous. Vague phrasing should trigger another `AskUserQuestion` to tighten it.
4. **Common areas that almost always need explicit user answers**:
   - Feature scope and boundaries (in vs explicitly out)
   - User types, permissions, anonymous vs authenticated
   - Currency, locale, numeric defaults (tax rates, service charge rates, etc.)
   - Failure-mode behavior (network down, parse error, empty input)
   - Persistence and history
   - Sharing and export to other apps

Use `AskUserQuestion` (grouped, ≤4 at a time) and only proceed to step 6 (`create_feature`) after every gap is resolved.

### Success Criteria Guidelines

Success criteria must be:

1. **Measurable**: Include specific metrics (time, percentage, count, rate)
2. **Technology-agnostic**: No mention of frameworks, languages, databases, or tools
3. **User-focused**: Describe outcomes from user/business perspective, not system internals
4. **Verifiable**: Can be tested/validated without knowing implementation details

**Good examples**:

- "Users can complete checkout in under 3 minutes"
- "System supports 10,000 concurrent users"
- "95% of searches return results in under 1 second"
- "Task completion rate improves by 40%"

**Bad examples** (implementation-focused):

- "API response time is under 200ms" (too technical, use "Users see results instantly")
- "Database can handle 1000 TPS" (implementation detail, use user-facing metric)
- "React components render efficiently" (framework-specific)
- "Redis cache hit rate above 80%" (technology-specific)
