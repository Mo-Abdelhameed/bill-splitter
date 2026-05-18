# Specs

Source of truth for what this project does. Every code change traces to a story here.

## Story format

```
# Story: [short title]
ID: STORY-NNN
Status: draft | in-progress | pending-verification | done | superseded
Feature: [feature folder name]
Depends on: STORY-XXX, STORY-YYY    # optional, omit if independent
Supersedes: STORY-ZZZ                # optional
Superseded by: STORY-AAA             # optional, set when this story is superseded

## Intent
As a [user type], I want [capability], so that [outcome].

## Context
2-3 sentences: why this matters, what it replaces or enables, non-obvious constraints.

## Acceptance Criteria
- [ ] AC-1 [behavioral]: Given [state], when [action], then [observable outcome]
- [ ] AC-2 [visual @mobile]: At viewport 375px, [specific visual property]
- [ ] AC-3 [behavioral]: ...

## Non-goals
- [explicit things this story does NOT cover]

## Verification notes
[Optional. Populated by the verifier when it finds gaps, or by the author when there is something specific the verifier should know.]
```

## Rules

- **IDs are global and sequential.** STORY-001, STORY-002, etc. Never reused.
- **Filenames** are `STORY-NNN-<kebab-slug>.md`.
- **Feature folders** group by domain (checkout, auth, search), not by layer (frontend, api).
- **AC are testable.** Each AC must be expressible as a test or a checkable visual observation. If you cannot, rewrite the AC.
- **AC are tagged** `[behavioral]` (default) or `[visual @viewport]` where viewport is one of `mobile`, `tablet`, `desktop`, or `all`. For this Flutter mobile project, `mobile` maps to the iPhone 17 simulator or the Medium_Phone Android emulator, `tablet` is out of scope unless a story explicitly needs it, `desktop` is not applicable.
- **Non-goals matter.** They prevent scope creep during implementation.
- **Status transitions:**
  - `draft` → `in-progress` when implementation starts
  - `in-progress` → `pending-verification` when implementer believes AC are met and full test suite passes
  - `pending-verification` → `done` only by the verifier sub-agent
  - `pending-verification` → `in-progress` if verifier finds gaps
  - any → `superseded` when explicitly replaced by another story
- **Dependencies are declared, not derived.** Only list `Depends on` when the new story is impossible or incoherent without the listed story being done first. Thematic relatedness is not a dependency.
- **Never hand-edit `index.json`.** Run `scripts/spec/regen-index` instead.

## Test naming convention

Tests that verify AC must be named with the story and AC reference:

```
STORY-014 AC-1: empty cart, addItem, item appears with quantity 1
```

In Flutter / Dart, this maps to:

```dart
test('STORY-014 AC-1: empty cart, addItem, item appears with quantity 1', () {
  // ...
});
```

This lets the verifier and affected-story discovery map tests to stories via test output and grep.

## Workflow

1. Human describes a feature in plain language.
2. `spec-author` skill drafts the story, human confirms, file is saved, index is regenerated.
3. Implementer reads the story, sets status to `in-progress`.
4. For each `[behavioral]` AC: write a failing test before implementing.
5. Implement code until AC tests pass. Refactor with tests green.
6. Implementer runs full suite. Once green, sets status to `pending-verification`.
7. Hook triggers `verifier` (and `ui-verifier` if visual AC present).
8. Pass → status `done`. Fail → status `in-progress` with verification notes.

## What lives where

- Stories: `specs/features/<feature>/STORY-NNN-*.md`
- Derived index: `specs/index.json`
- Spec format reference: this file
- Skill: `.claude/skills/spec-author/`
- Sub-agents: `.claude/agents/verifier.md`, `.claude/agents/ui-verifier.md`
- Scripts: `scripts/spec/`
