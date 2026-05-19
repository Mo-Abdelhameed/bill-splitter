---
name: implement-story
description: Use this skill when the user wants the full TDD flow for a story end-to-end. Trigger phrases include "implement STORY-X end to end", "do the full TDD for STORY-X", "complete STORY-X", "/implement-story STORY-X". Composes `implement-tests` (red phase) and `implement-feature` (green phase) into a single workflow. Writes failing tests for any uncovered behavioral AC, then implements the feature code until all tests pass and Status transitions to `pending-verification`.
---

# implement-story

You are doing the full TDD flow for a story: **red** (failing tests for every uncovered `[behavioral]` AC), then **green** (feature code under `lib/` that makes them pass). This skill composes `implement-tests` and `implement-feature` in sequence. The full rules from both apply.

## Inputs

A story ID (e.g., `STORY-001`). If not provided in the invocation, ask the user which story to work on before doing anything else.

## Process

1. **Read the story file** at `specs/features/<feature>/STORY-NNN-*.md` in full. Identify all `[behavioral]` AC and all `[visual]` AC.

2. **Phase 1 — Tests (apply the `implement-tests` workflow):**
   - Set Status to `in-progress` if currently `draft`.
   - For each `[behavioral]` AC: if a test named `STORY-NNN AC-N: ...` already exists in `test/`, skip; otherwise, write a failing test and confirm it fails for the right reason.
   - Skip every `[visual]` AC (handled later by `ui-verifier`).
   - Do not modify any file under `lib/` in this phase.
   - Full rules: read [`.claude/skills/implement-tests/SKILL.md`](../implement-tests/SKILL.md) and follow it.

   If phase 1 finishes and no new tests were written because every behavioral AC already had a test, proceed straight to phase 2.

3. **Phase 2 — Feature (apply the `implement-feature` workflow):**
   - Verify every `[behavioral]` AC now has a test (it should, after phase 1).
   - Implement code under `lib/` until every per-AC test passes.
   - Run `flutter test` (full suite) — every test in the project must pass.
   - Run `flutter analyze` — zero errors required.
   - Set Status to `pending-verification`, which triggers the verifier (and `ui-verifier` if `[visual]` AC are present) via the PostToolUse hook.
   - Full rules: read [`.claude/skills/implement-feature/SKILL.md`](../implement-feature/SKILL.md) and follow it.

   If phase 2 finds that all tests already pass before any code change, halt and ask the user — either the feature is already implemented or the tests are not exercising real behavior. Do not silently transition Status.

4. **Output a combined summary**:
   - Phase 1: AC for which a new failing test was written, AC for which an existing test was reused, AC skipped because `[visual]`.
   - Phase 2: files created or modified under `lib/`, build_runner runs if any.
   - Final gates: full suite passing, `flutter analyze` clean, Status transitioned to `pending-verification`.
   - Reminder: the verifier (and ui-verifier if applicable) will be invoked via the hook; await their judgment before considering the story complete.

## Important behaviors

The rules from both `implement-tests` and `implement-feature` apply here in full. The most important ones are repeated for emphasis:

- **Ask the user when you sense a gap**, in either phase, no matter how small the gap. The "ask, don't assume" rule applies here exactly as it does in `spec-author`.
- **Tests must fail for the right reason** at the end of phase 1 before you begin phase 2. If phase 1 leaves a test failing because of a typo or missing import, fix it before moving on.
- **Do not modify tests to make them pass** during phase 2. The tests are the AC made executable. If a test seems wrong, raise it to the user.
- **Do not modify the AC text** in the story file from either phase.
- **Do not mark the story `done`** from this skill. Only the verifier sub-agent has that authority.
- **Do not suppress `flutter analyze` errors** to clear the gate. Fix them or ask.

If at any point you realize the AC are contradictory, the story is missing a critical detail, or the implementation needs an architectural decision the story does not specify — stop both phases and ask the user. Do not push through silently.
