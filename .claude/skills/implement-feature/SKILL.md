---
name: implement-feature
description: Use this skill when the user wants to implement the feature code for a story whose behavioral tests are already written. Trigger phrases include "implement STORY-X", "make the tests pass for STORY-X", "build the feature for this story", or any time the user is at the "make-it-green" phase of TDD. Halts with a clear error if any [behavioral] AC lacks a corresponding test — the user must run `implement-tests` first.
---

# implement-feature

You are implementing feature code under `lib/` so that the existing failing tests for a story start passing. You do NOT write tests in this skill — tests must already exist. This is the "green" phase of the TDD workflow defined in `CLAUDE.md`.

## Inputs

A story ID (e.g., `STORY-001`). If not provided in the invocation, ask the user which story to work on before doing anything else.

## Process

1. **Read the story file** in full. Identify all `[behavioral]` AC and all `[visual]` AC.

2. **Verify a test exists for every `[behavioral]` AC.** For each AC, use Grep against `test/` to find a test named `STORY-NNN AC-N: ...`. If any AC lacks such a test, HALT immediately. Output:
   - The AC numbers that lack tests.
   - The instruction: "Run `implement-tests STORY-NNN` first, then re-invoke `implement-feature`."
   Do not proceed past this step until every behavioral AC has a test.

3. **Verify Status is `in-progress`**:
   - If `draft`, set Status to `in-progress`.
   - If `pending-verification` or `done`, halt and ask the user. The story is past the implementation phase; the user may have meant a different story or wants to redo something.
   - If `superseded`, halt — superseded stories are not implemented.

4. **Run the relevant tests now** to confirm they fail. `flutter test test/path/...` for each test file that contains AC tests for this story. If they all already pass, halt and ask the user — either the feature is already implemented, or the tests are not exercising real behavior. Do not silently proceed.

5. **Implement code under `lib/` until all `[behavioral]` AC tests pass.** Approach:

   a. Pick one AC at a time. Read its test. Implement just enough code in `lib/` to make that test pass. Run the test. Move to the next AC. This is the inner red-green loop.

   b. Mirror the test directory under `lib/`: code that satisfies a test in `test/screens/foo_test.dart` belongs at `lib/screens/foo.dart`. Riverpod providers, models, services follow the same mirroring convention.

   c. If the story touches generated code (Riverpod `@riverpod`, Hive `@HiveType`, `json_serializable`), run `dart run build_runner build --delete-conflicting-outputs` before re-running tests. `CLAUDE.md` notes this requirement.

   d. After each meaningful Edit/Write under `lib/`, the PostToolUse hook (Hook 1) runs the matching test file automatically. Use that signal; do not redundantly invoke `flutter test` for the same file.

6. **Once all per-AC tests pass**, run the full suite: `flutter test`. Every test in the project must pass — not only the new AC tests. If a pre-existing test fails, you have introduced a regression; fix it before continuing. If you cannot tell whether the failure is a regression or pre-existing brokenness, stop and ask the user.

7. **Run `flutter analyze`.** Zero errors are required to transition Status (warnings are acceptable). Fix any errors before continuing. If an error is non-trivial and you are unsure of the right fix, stop and ask.

8. **Set Status to `pending-verification`** by editing the story file's Status line. This triggers the PostToolUse hook, which re-runs the full Flutter test suite as a final gate and, on pass, emits a system message asking the main agent to invoke the `verifier` sub-agent (and `ui-verifier` if the story has any `[visual]` AC). Do NOT mark the story `done` yourself — only the verifier has that authority.

9. **Output a summary**:
   - List of files created or modified under `lib/`.
   - Confirmation that all per-AC tests pass.
   - Confirmation that the full Flutter suite passes.
   - Confirmation that `flutter analyze` is clean (zero errors).
   - Confirmation that Status is now `pending-verification`.
   - Reminder: the verifier (and ui-verifier if applicable) will be invoked via the hook; await their judgment.

## Important behaviors

- **Ask the user when you sense a gap.** If an AC is ambiguous, if implementation requires an architectural decision the story does not specify (state management shape, persistence approach, package choice), or if the test setup makes the AC's intent unclear — stop and ask. Do not silently choose.
- **Do not modify tests to make them pass.** Tests are the source of truth derived from the AC. If a test looks wrong, raise it to the user. Never change a test's assertion or name to coerce it to green.
- **Do not modify AC text in the story.** Same principle — the story is source of truth.
- **Do not transition Status to `done`.** That is the verifier's authority alone.
- **Do not work around `flutter analyze` errors.** No `// ignore:`, no suppressions, no `dynamic` to dodge type errors. If an analyze error is hard, ask the user. Analyze errors usually mean something real is broken.
- **If the AC are contradictory** (e.g., AC-1 requires X, AC-3 requires not-X), stop. Ask the user; do not try to satisfy contradictory criteria.
- **Don't write tests.** Hard rule. If you find yourself adding a new test under `test/` to validate your implementation, stop — those should have been written by `implement-tests` first. If a test is genuinely missing, halt per step 2.
