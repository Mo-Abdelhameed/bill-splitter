---
name: "read-constitution"
description: "Pull the canonical constitution from the specs DB and refresh the snapshot in CLAUDE.md so the principles stay in every session's context. Pass --check to detect drift without writing."
argument-hint: "--check to only detect drift without writing"
user-invocable: true
disable-model-invocation: false
---


## User Input

```text
$ARGUMENTS
```

## What this skill does

Synchronizes CLAUDE.md's `<!-- CONSTITUTION START -->` / `<!-- CONSTITUTION END -->` block with the canonical constitution in the specs DB.

The DB is the **source of truth**. CLAUDE.md is the **always-in-context snapshot** — it's auto-loaded into every session, so inlining the constitution here is what makes "the agent always knows the constitution" a hard guarantee instead of a wish.

Run this skill:
- After amending the constitution in the DB.
- As the final step of any future `/amend-constitution`-style skill.
- With `--check` to verify drift without writing (cheap pre-commit gate).

## Outline

1. **Parse arguments.** If `$ARGUMENTS` contains the token `--check`, set `CHECK_MODE = true`; otherwise `CHECK_MODE = false`.

2. **Fetch the canonical constitution from the DB:**
   ```
   result = mcp__specs-mcp__get_constitution(project='PROJECT_NAME')
   ```
   The response contains:
   - `version`: string (e.g. `"1.1.0"`)
   - `body`: markdown for everything *except* the principles (preamble, Technology Constraints, Development Workflow & Quality Gates, Governance, amendment log)
   - `principles`: list of `{ordinal, name, non_negotiable, body}` already ordered by ordinal

3. **Format the snapshot** as one markdown block, exactly in this shape:

   ```markdown
   <!-- CONSTITUTION START -->
   _Constitution v{version} — snapshot from the specs DB (canonical source).  
   Last synced from DB: YYYY-MM-DD. **If this drifts from the DB, trust the DB**
   and re-run `/read-constitution`._

   ### Core Principles

   #### I. {principle 1 name}{ " (NON-NEGOTIABLE)" if non_negotiable }

   {principle 1 body}

   #### II. {principle 2 name}{ " (NON-NEGOTIABLE)" if non_negotiable }

   {principle 2 body}

   #### III. {principle 3 name}{ " (NON-NEGOTIABLE)" if non_negotiable }

   {principle 3 body}

   #### IV. {principle 4 name}{ " (NON-NEGOTIABLE)" if non_negotiable }

   {principle 4 body}

   #### V. {principle 5 name}{ " (NON-NEGOTIABLE)" if non_negotiable }

   {principle 5 body}

   ### Other Constitutional Sections

   {body}
   <!-- CONSTITUTION END -->
   ```

   Conventions:
   - Use Roman numerals (`I`, `II`, `III`, `IV`, `V`) for `ordinal` 1–5. For higher ordinals, fall back to `<ordinal>.`.
   - If the DB returns fewer than 5 principles, emit only the ones present.
   - If `non_negotiable` is `true`, append the literal `" (NON-NEGOTIABLE)"` to the heading.
   - Trim trailing whitespace from each principle body but preserve internal markdown formatting (lists, code blocks, links).

   **Body (`{body}`) requires three transformations before insertion** — the raw `constitution_body` from the DB contains an H1 title and a duplicate Core Principles section that would collide with the structure above. Apply IN ORDER:
   1. **Strip the leading H1 title line** (any line starting with `# ` before the first H2). The DB body often begins with `# Bill Split Constitution`; remove it entirely.
   2. **Skip the duplicate `## Core Principles` section.** Drop every line from `## Core Principles` until (but not including) the next `## ` heading. The principles already appear above in the "### Core Principles" block.
   3. **Shift remaining heading levels down by 1** (cap at H6): `##` → `###`, `###` → `####`, `####` → `#####`, etc. This nests the body's sections under the project-level H2 wrapper that CLAUDE.md introduces.

   After these transformations, the body should contain only the post-principles sections (Technology Constraints, Development Workflow & Quality Gates, Governance, amendment log, version footer) at H3+ depth.

4. **Read the current CLAUDE.md** at `/Users/mo/Desktop/bill-splitter/CLAUDE.md`.
   - If the markers `<!-- CONSTITUTION START -->` and `<!-- CONSTITUTION END -->` are present: extract the existing block between them.
   - If the markers are absent: the block doesn't exist yet. You'll create it in step 7 (only if not in CHECK_MODE).

5. **Diff.** Compare the freshly-formatted snapshot (step 3) against the existing block (step 4).
   - Compute a short summary of what changed:
     - Version bump (e.g. `v1.1.0 → v1.2.0`)
     - Principles added / removed (by ordinal + name)
     - Principles whose body text changed (list by ordinal)
     - Non-negotiable flag flips (by ordinal: `non_negotiable: false → true` or vice versa)
     - Whether `body` (the non-principle blob) changed

6. **If `CHECK_MODE` is true:**
   - If the diff summary is empty: print
     ```
     ✓ CLAUDE.md is in sync with the constitution in the DB.
     Version: {version}
     Principles: N (M non-negotiable)
     ```
   - If non-empty: print
     ```
     ✗ DRIFT DETECTED — CLAUDE.md is out of sync with the DB.

     {diff summary}

     Re-run `/read-constitution` (without --check) to update.
     ```
   - Do NOT write to CLAUDE.md. Exit.

7. **If `CHECK_MODE` is false:**
   - **If the markers exist in CLAUDE.md:** use the `Edit` tool to replace the block (including the markers themselves) with the new snapshot from step 3. Match on the exact strings `<!-- CONSTITUTION START -->` through `<!-- CONSTITUTION END -->`.
   - **If the markers DO NOT exist yet:** find a sensible insertion point. Recommended: just BEFORE the `## Implementation conventions (for the rebuild)` section (or, if that header isn't there, immediately after the `## Principle IV: Ask, Don't Assume` section). Insert the entire snapshot from step 3, with a preceding blank line for readability. Surround it with a new section header like `## Constitution (snapshot — DB is source of truth)\n\n<!-- CONSTITUTION START -->\n...\n<!-- CONSTITUTION END -->\n` so the markers stay inside the section.

8. **Report the result.** Print one of:

   ```
   ✓ CLAUDE.md updated.

   Constitution version: {version}
   Principles: N (M non-negotiable)
   Body length: X chars

   Changes since previous snapshot:
     • <diff line 1>
     • <diff line 2>
     ...
   ```

   Or, if the snapshot was identical and no write happened:

   ```
   ✓ CLAUDE.md was already in sync. No write performed.
   Constitution version: {version}
   ```

## Constraints

- Do **not** touch any part of CLAUDE.md outside the marker block (or outside the new section being created). One Edit call, narrow scope.
- Do **not** mutate the DB. This skill is read-only against the specs DB; it only writes to CLAUDE.md.
- Do **not** invent principles or fabricate ordinals — pass through exactly what the DB returns.
- Do **not** ask the user any questions. This skill is mechanical; if the DB lookup fails, surface the error and stop.

## Why this skill exists

CLAUDE.md is the only artifact in Claude Code that is **guaranteed to be in every session's system context**. MCP resources, skill bodies, and tool outputs are all opt-in — the agent has to actively read them. By inlining a snapshot of the constitution here, the project's law is unmissable for any agent (including sub-agents that load CLAUDE.md). The DB stays canonical so structured queries still work; this skill just keeps the visible copy current.
