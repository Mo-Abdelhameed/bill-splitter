# Working in this project

This is a Flutter mobile app (iOS + Android) — a bill splitter for Egyptian restaurants. The strategic plan lives in `specs/docs/bill_split_plan.md` and is divided into phases. The tactical units of work are **stories** under `specs/features/`. Each story maps to one or more phase items and trims them down to a single shippable, verifiable behavior.

## Spec-driven workflow

This project uses spec-driven development. Before writing or changing any code:

1. **Find or create the relevant story.** Check `specs/index.json` to see existing stories. If the work does not fit any existing story, ask the user to discuss requirements first — the `spec-author` skill will draft a story.

2. **Read the story in full** before implementing. Pay attention to AC and non-goals.

3. **Set the story status to `in-progress`** when you start work. The index auto-regenerates via hook.

4. **Write tests first for `[behavioral]` AC.** For each AC, write a failing test before implementing. Name tests `STORY-NNN AC-N: <description>`. Confirm tests fail for the right reason (not syntax errors or missing imports). In Flutter/Dart, this looks like:
   ```dart
   test('STORY-014 AC-1: empty cart, addItem, item appears with quantity 1', () {
     // ...
   });
   ```

5. **Implement code until AC tests pass.** Refactor with tests green.

6. **When all AC are met**, run the full test suite (`flutter test`). Once green, set the story status to `pending-verification`. The verifier (and ui-verifier if visual AC present) will be triggered automatically by the hook. Do not mark a story `done` yourself — only the verifier does that.

7. **If the verifier returns the story to `in-progress`** with notes, address the notes and re-submit.

8. **For changes not tied to a single story** (refactors, bug fixes across modules): make the change, then expect the verifier hook to re-check affected `done` stories. If it flags regressions, fix them before committing.

The full format and workflow are in `specs/README.md`. The skill that drafts stories is `spec-author`. The sub-agents that verify are `verifier` and `ui-verifier`.

## Flutter-specific conventions

- **Test runner**: `flutter test` (full suite) or `flutter test test/path/foo_test.dart` (single file). No `--related` mode exists; the hook router handles per-file mapping (`lib/X.dart` → `test/X_test.dart`).
- **Source layout**: implementation under `lib/`, tests under `test/`. Mirror the directory structure between the two so the hook can find related tests.
- **State management**: Riverpod (`flutter_riverpod` + `riverpod_annotation` + `riverpod_generator`). Run `dart run build_runner build --delete-conflicting-outputs` after adding new `@riverpod` annotations.
- **UI verification**: this app has no web target. `ui-verifier` uses `mobile-mcp` to screenshot the running iPhone 17 simulator and/or Medium_Phone Android emulator instead of a browser. `[visual @mobile]` AC are checked on both platforms when feasible.
- **Linting/static analysis**: `flutter analyze` should pass with zero errors before any story moves to `pending-verification`.
- **Build runner**: when stories touch generated code (Riverpod, Hive adapters, json_serializable), regenerate before running tests: `dart run build_runner build --delete-conflicting-outputs`.

## Where things live

- Strategic plan: `bill_split_plan.md` (or `docs/`) — phases, broad scope.
- Stories: `specs/features/<feature>/STORY-NNN-*.md` — tactical units, AC.
- Index: `specs/index.json` — auto-generated, never edit by hand.
- Spec format reference: `specs/README.md`.
- Skill: `.claude/skills/spec-author/SKILL.md`.
- Sub-agents: `.claude/agents/verifier.md`, `.claude/agents/ui-verifier.md`.
- Hook dispatcher: `scripts/spec/hook-router` (configured in `.claude/settings.json`).
- Index builder: `scripts/spec/regen-index`.
