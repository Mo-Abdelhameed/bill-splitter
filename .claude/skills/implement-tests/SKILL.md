---
name: implement-tests
description: Use this skill when the user wants to write failing tests for a story's behavioral acceptance criteria without implementing the feature itself. Trigger phrases include "write the tests for STORY-X", "TDD step 1 for STORY-X", "create the failing tests for this story", or any time the user wants the test-first phase of TDD on its own. Skips [visual] AC (those are handled by the ui-verifier sub-agent) and skips AC that already have a test in the codebase.
---

# implement-tests

You are writing failing tests for a story's behavioral acceptance criteria. You do NOT implement the feature itself — only the tests. This is the "red" phase of the TDD workflow defined in `CLAUDE.md`.

## Inputs

A story ID (e.g., `STORY-001`). If not provided in the invocation, ask the user which story to work on before doing anything else.

## Process

1. **Read the story file** at `specs/features/<feature>/STORY-NNN-*.md` in full. Identify all `[behavioral]` AC. Note all `[visual]` AC — those will be skipped. Also read `specs/README.md` and `CLAUDE.md` if you have not already in this session.

2. **Set Status to `in-progress`** if currently `draft`. Edit the story file's Status line. The index regenerates automatically via the PostToolUse hook.

3. **For each `[behavioral]` AC**, in order:

   a. **Check for an existing test** named with the AC's identifier prefix (`STORY-NNN AC-N: ...`). Use Grep against `test/`. If a test starting with this name exists anywhere under `test/`, SKIP this AC entirely and note it in your output. Per project rule, do not overwrite existing tests; leave them untouched.

   b. **Determine the test file** for the AC. Mirror the `lib/` directory layout under `test/`:
      - AC about widget rendering, taps, gestures, navigation → `test/<area>/<screen-or-widget>_test.dart` using `testWidgets()`.
      - AC about pure logic (calculations, data transforms, validators) → `test/<area>/<unit>_test.dart` using `test()`.
      Create the file if it does not exist. Reuse an existing test file when one already covers the same widget/unit.

   c. **Write a failing test**. Name it exactly `'STORY-NNN AC-N: <description copied from the AC>'`. Translate the AC's Given/When/Then into setup, action, and assertion. The test must demonstrate that the AC is NOT yet satisfied — typically by referencing a class/widget/function that does not yet exist in `lib/`, which causes a compile or import error.

   d. **Run the test** with `flutter test test/path/to/file_test.dart`. Confirm it fails. Critically, confirm it fails for the RIGHT reason — the assertion under test, or a missing-implementation error. If it fails for the wrong reason (syntax in the test, missing test-only dependency, typo in an import that has nothing to do with the AC), fix the test setup and run again. The end state for each AC is "test compiles, test runs, test fails because the feature is not implemented yet."

4. **Skip every `[visual]` AC.** Visual AC are verified at `pending-verification` time by the `ui-verifier` sub-agent using `mobile-mcp` screenshots — not by Flutter test files. Note in your output which AC were skipped for this reason.

5. **Do NOT modify any file under `lib/`.** This skill writes tests only. If a test needs a class/widget/function that does not exist, that missing-implementation is the EXPECTED failing state for the AC. Creating that implementation is the next skill's job (`implement-feature`).

6. **Output a summary**:
   - List of AC for which a test was written, with the test file path and the exact test name.
   - List of AC skipped because an existing test was already in place (with the path to that existing test).
   - List of AC skipped because they were `[visual]`.
   - Confirmation that every newly written test currently fails for the right reason.
   - Suggested next step: invoke `implement-feature STORY-NNN` (or `implement-story` if the user wants the full flow continued).

## Important behaviors

- **Ask the user when you sense a gap**, regardless of how small. If an AC is ambiguous, if you do not understand what to test, or if there are two equally reasonable test designs and the choice matters, stop and ask. Do not silently pick.
- **Never modify the AC text in the story.** The story is the source of truth; the test must match its current wording. If you think the AC is wrong, flag it to the user — but do not unilaterally edit the story file from this skill.
- **Tests must compile.** `flutter test` refuses to run if test files have analyze errors. Resolve those before declaring a test "failing for the right reason."
- **Do not transition Status beyond `in-progress`.** This skill's success state is "Status is `in-progress` and every uncovered behavioral AC has a failing test." Status moves to `pending-verification` only after the feature is implemented.
- **Do not write feature code.** Hard rule. If you find yourself editing `lib/` to make a test pass, stop — that's `implement-feature`.
- **Do not invoke the verifier or ui-verifier.** Those run only when Status reaches `pending-verification`, which this skill never sets.
