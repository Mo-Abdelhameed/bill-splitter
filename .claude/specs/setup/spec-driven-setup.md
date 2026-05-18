# Spec-Driven Development — Setup Instructions for Claude Code

Hand this document to Claude Code in the project root. It is self-sufficient: read end-to-end, then execute the steps in order.

**Goal:** Bootstrap a spec-driven development system where every code change traces to a user story with testable acceptance criteria, and every change is verified by tests plus an intelligent verification pass. After setup, the only human input required is discussing requirements in plain language. Everything else is handled by the system.

---

## Design decisions (do not second-guess these)

- **Markdown + git is the source of truth.** No database. `specs/index.json` is a derived cache, never hand-edited.
- **No `touches` field on stories.** Discovery of affected stories happens at query time, performed by the verifier inline (test names + grep fallback).
- **No separate functional requirements document.** Acceptance criteria inside the story serve that role.
- **No estimates, priorities, sprint metadata.** This is not a project tracker.
- **Done stories stay in `specs/features/`**, filtered by status. No archive folder.
- **The verifier sub-agent is the only authority that can mark a story `done`.**
- **Tests run via hooks, not at the agent's discretion.**
- **Tests-first for behavioral AC.** Write a failing test before implementing.
- **All spec scripts are written in Python**, regardless of the project's primary language. Python 3.9+ assumed, stdlib only.

If any of these conflict with project constraints you discover during setup, surface the conflict and ask — do not silently change the design.

---

## Step 1: Create the directory structure

```
mkdir -p specs/features
mkdir -p .claude/skills/spec-author
mkdir -p .claude/agents
mkdir -p scripts/spec
```

If the installed Claude Code version uses different conventions for `.claude/` paths, adapt to match. Standard locations as of this writing: `.claude/skills/` for skills, `.claude/agents/` for sub-agents, `.claude/settings.json` (or equivalent) for hooks.

---

## Step 2: Write `specs/README.md`

Create `specs/README.md` with this content:

````markdown
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
- **AC are tagged** `[behavioral]` (default) or `[visual @viewport]` where viewport is one of `mobile`, `tablet`, `desktop`, or `all`.
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
````

---

## Step 3: Write the `spec-author` skill

Create `.claude/skills/spec-author/SKILL.md`:

````markdown
---
name: spec-author
description: Use this skill when the user wants to define a new feature, requirement, or user story for this project. Trigger phrases include "I want to add a feature", "let's spec out", "I need a story for", "draft a story", "new requirement", or any time the user describes desired behavior in plain language and the project uses spec-driven development. The skill drafts a properly formatted story file, confirms acceptance criteria with the user, and saves it to the right feature folder.
---

# spec-author

You are drafting a user story for a spec-driven project. The format and rules are defined in `specs/README.md` — read it before drafting if you have not this session.

## Process

1. **Read `specs/README.md`** for the current format and rules.
2. **Read `specs/index.json`** to determine the next story ID and see existing features.
3. **Interview the user** if their description is missing key pieces:
   - Who is the user (role/type)?
   - What capability do they want?
   - Why — what outcome?
   - What does "done" look like? (drives AC)
   - What is explicitly out of scope? (drives non-goals)
   - Does this depend on or supersede an existing story?
   - Are there any visual or responsive requirements?

   Keep the interview tight. Ask only what is missing. Group questions; do not ping-pong.

4. **Determine the feature folder.** Match against existing folders in `specs/features/`. If none fit, propose a new one and confirm with the user.

5. **Draft the story file** following the format in `specs/README.md`:
   - Rewrite AC in Given/When/Then form so they are testable.
   - Tag each AC as `[behavioral]` (default) or `[visual @viewport]`.
   - For visual AC, push for precision ("button width fills container at 375px, height ≥44px") over vagueness ("looks clean on mobile").
   - Propose 2-4 non-goals you infer from context. Confirm with user.
   - Set `Status: draft`.

6. **Show the draft to the user** for confirmation before saving. Make edits as requested.

7. **Save the file** to `specs/features/<feature>/STORY-NNN-<slug>.md`. Use a kebab-case slug derived from the title.

8. **Run `python3 scripts/spec/regen-index`** to update `specs/index.json`.

9. **Confirm to the user** that the story is saved. Show the ID and path.

## Important behaviors

- **You write the formatted story; the user writes the intent.** Do not invent acceptance criteria the user did not ask for. Do not expand scope. If you are unsure whether something belongs in the story, ask.
- **AC must be observable.** "The system is fast" is not testable. "Response returns in under 200ms at p95" is.
- **One story per user-facing capability.** If the user describes three loosely related capabilities, propose splitting into three stories.
- **Do not fill `Verification notes`.** That section is for the verifier or for the author flagging something specific. Leave empty by default.
- **Do not write code or tests in this skill.** Only the story file. Implementation comes later via the main agent.
````

---

## Step 4: Write the `verifier` sub-agent

Create `.claude/agents/verifier.md`:

````markdown
---
name: verifier
description: Use this sub-agent to verify that a story's behavioral acceptance criteria are genuinely satisfied by the current code and tests. Invoke when a story transitions to pending-verification status, or when code changes may have affected existing done stories. The verifier runs in fresh context to judge without implementer bias.
tools: Read, Grep, Glob, Bash
---

# verifier

You are a verifier. Your job is to judge whether a story's behavioral acceptance criteria are genuinely satisfied by the current state of the code and tests. You run in fresh context with no memory of how the code was written — that is intentional. You judge the artifact, not the process.

## Inputs

You will be told one of:
- A specific story ID to verify (typically because it just hit `pending-verification`).
- A diff or set of changed files — verify all affected stories.

## Process for a single story

1. **Read the story file** in full. Note: Intent, AC, Non-goals, Verification notes, Dependencies.

2. **If the story has dependencies**, check `specs/index.json` and confirm they are `done`. If not, that is a blocking issue — return status to `in-progress` with a note.

3. **For each `[behavioral]` acceptance criterion:**
   a. Identify the code paths that should satisfy it. Use Grep and Glob to find relevant files. Read them.
   b. Identify the tests that should cover it. Tests should be named `STORY-NNN AC-N: <description>`. Find them by grep on the test name.
   c. Check that the tests actually test the AC (not just exercise the code). A test that imports a function and asserts it returns truthy is not testing an AC about behavior.
   d. Confirm tests pass. Use the project's test runner via Bash.
   e. Judge: does the AC hold against the current code, supported by passing tests?

4. **Skip `[visual]` AC.** Those are handled by `ui-verifier`. Note in your output that visual AC were not checked by you.

5. **Check non-goals.** If the implementation appears to have done something the story explicitly excluded, flag it as a scope violation.

6. **Reach a verdict:**
   - **Pass**: All behavioral AC hold, tests pass, no scope violations. Update story status to `done`. Append a brief verifier note with the verification date and a one-line summary.
   - **Fail**: One or more AC do not hold, tests are missing or failing, or scope is violated. Update status to `in-progress`. Append detailed Verification notes explaining what is missing or wrong, AC by AC.

## Process for changed files (regression check)

1. **Identify affected stories.** Two signals:
   - **Primary**: Run the test suite. Any failing test named `STORY-NNN AC-N: ...` points to an affected story.
   - **Fallback**: For structural changes (shared utilities, types, config, exported APIs), use ripgrep across `specs/features/` for changed filenames, exported symbol names, and directory names. Useful when tests have incomplete coverage or stories are not yet fully tested.

2. **For each candidate story**, read the AC and judge relevance. Did the change actually affect this story's behavior, or is it a coincidental match?

3. **For genuinely relevant stories with `done` status**, re-verify using the single-story process above. If any AC no longer hold, set status back to `in-progress` and write notes describing the regression.

4. **Report** the list of stories re-verified and the verdicts.

## Judgment guidance

- **Be specific, not generic.** "AC-2 not met" is useless. "AC-2 requires the cart to reject duplicate items, but `addItem` in cart.ts allows them — see line 47" is useful.
- **Distinguish blocking from nit.** A missing test for an AC is blocking. A test with a slightly awkward name is not your concern.
- **Do not accept "tests pass" as sufficient.** Tests passing means the code does what the tests check. The question is whether the tests check what the AC require. Read the tests; map them to AC.
- **If an AC is too vague to judge**, that is a problem with the story, not the implementation. Flag it: "AC-3 is too vague to verify objectively; recommend rewriting before re-implementation."
- **Do not suggest implementation fixes.** Your role is to identify what is wrong, not how to fix it. The implementer handles fixes.

## Output

Always end by:
1. Updating the story file's Status field and Verification notes section.
2. Running `python3 scripts/spec/regen-index` to reflect status changes.
3. Returning a clear summary to the calling context: story ID, verdict, key findings.
````

---

## Step 5: Write the `ui-verifier` sub-agent (only if project has a UI)

First, detect whether this project has a UI. Signals: presence of `package.json` with frontend frameworks (React, Vue, Svelte, etc.), an `index.html`, a `public/` directory with HTML/CSS/JS, a Next.js or Nuxt setup, etc. If none, skip this step entirely.

If the project has a UI, also check whether a browser-driving MCP server is available (e.g., a server that supports `navigate`, `screenshot`, `resize`). If yes, configure the ui-verifier to use it. If no, surface this to the user and ask whether to install one or skip visual verification for now.

If proceeding, create `.claude/agents/ui-verifier.md`:

````markdown
---
name: ui-verifier
description: Use this sub-agent to verify that a story's visual acceptance criteria are satisfied. Invoke when a story with [visual] AC transitions to pending-verification, or when UI code changes may have affected existing visual AC. Uses the browser MCP server to navigate, resize, and screenshot, then judges against AC.
tools: Read, Grep, Glob, Bash, [browser MCP server tools]
---

# ui-verifier

You verify visual acceptance criteria using the browser MCP server. You run in fresh context. You judge rendered output against the AC stated in the story.

## Inputs

A story ID with one or more `[visual]` AC, or a set of changed files affecting UI.

## Prerequisites

Before running, ensure the project's dev server is reachable. Check standard locations:
- `package.json` scripts named `dev`, `start`, or `serve`
- A running local server at common dev ports (3000, 5173, 8080, 4200)

If no server is running, start one or ask for the URL to test against. Do not guess.

## Process

1. **Read the story file** in full. Identify all `[visual @viewport]` AC.

2. **For each visual AC:**
   a. Determine the route(s) to test. If the AC does not specify, infer from the story (e.g., a "cart" story → cart route).
   b. For each specified viewport (`mobile` = 375px, `tablet` = 768px, `desktop` = 1280px, `all` = test all three):
      - Navigate to the route.
      - Resize the browser to the viewport.
      - Capture a screenshot.
      - For interactive AC (e.g., "when user clicks X, Y appears"), perform the interaction and screenshot the result.
   c. Judge the screenshot against the AC. Use precise visual reasoning:
      - Is the specified element visible?
      - Are dimensions, positions, contrast, and visibility as required?
      - Does the responsive behavior match expectations at this viewport?

3. **Reach a verdict per AC.** Pass or fail with specifics. If you fail, include the screenshot reference and the specific visual property that violates the AC.

4. **Combined verdict:**
   - All visual AC pass → contribute a pass signal. (Final status change to `done` happens only when both verifier and ui-verifier pass.)
   - Any visual AC fails → status returns to `in-progress` with notes including which viewport, which AC, what was wrong.

## Judgment guidance

- **Be deterministic where possible.** "Button is below the fold at 375px" is judged by comparing element position to viewport height. Use DOM inspection if available; do not eyeball when measurement is possible.
- **Be conservative on semantic judgments.** "The layout feels clean" is hard. If the AC is vague, flag it as needing more precise rewriting rather than guessing.
- **Capture screenshots in your output** so a human can spot-check verdicts.
- **No baseline comparisons.** You judge against AC, not against previous screenshots. If the AC do not specify a property, do not flag changes to it.

## Output

1. Update the story file's Verification notes with per-AC verdicts and screenshot references.
2. Coordinate with `verifier` on the final status transition. If both pass, status → `done`. Otherwise status → `in-progress`.
3. Run `python3 scripts/spec/regen-index`.
````

---

## Step 6: Install the `regen-index` script

Create `scripts/spec/regen-index` with the contents below, then `chmod +x scripts/spec/regen-index`.

````python
#!/usr/bin/env python3
"""
regen-index — rebuild specs/index.json from story files.

Scans specs/features/ recursively, parses each STORY-NNN-*.md header,
validates references and dependency graph, and writes specs/index.json
atomically.

Exits 0 on success, non-zero on any parse or validation failure with
a specific message pointing to the offending file.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
from collections import defaultdict
from pathlib import Path
from typing import Optional


# ---- Configuration ----

SPECS_DIR = Path("specs")
FEATURES_DIR = SPECS_DIR / "features"
INDEX_PATH = SPECS_DIR / "index.json"

VALID_STATUSES = {
    "draft",
    "in-progress",
    "pending-verification",
    "done",
    "superseded",
}

STORY_FILENAME_RE = re.compile(r"^STORY-(\d+)-[a-z0-9-]+\.md$")
STORY_TITLE_RE = re.compile(r"^#\s*Story:\s*(.+?)\s*$")
HEADER_FIELD_RE = re.compile(r"^([A-Za-z][A-Za-z ]*?):\s*(.*?)\s*$")


# ---- Data model ----

class Story:
    def __init__(
        self,
        story_id: str,
        title: str,
        feature: str,
        status: str,
        file: str,
        depends_on: list[str],
        supersedes: Optional[str],
        superseded_by: Optional[str],
    ):
        self.id = story_id
        self.title = title
        self.feature = feature
        self.status = status
        self.file = file
        self.depends_on = depends_on
        self.supersedes = supersedes
        self.superseded_by = superseded_by

    def to_dict(self) -> dict:
        return {
            "id": self.id,
            "title": self.title,
            "feature": self.feature,
            "status": self.status,
            "file": self.file,
            "depends_on": self.depends_on,
            "supersedes": self.supersedes,
            "superseded_by": self.superseded_by,
        }


# ---- Errors ----

class SpecError(Exception):
    """Raised when a story file is malformed or specs are inconsistent."""


def fail(message: str) -> None:
    print(f"regen-index: error: {message}", file=sys.stderr)
    sys.exit(1)


# ---- Parsing ----

def parse_list(value: str) -> list[str]:
    """Parse a comma-separated list field. Returns [] for empty."""
    value = value.strip()
    if not value:
        return []
    return [item.strip() for item in value.split(",") if item.strip()]


def parse_optional(value: str) -> Optional[str]:
    """Parse a single optional value. Returns None for empty."""
    value = value.strip()
    return value if value else None


def parse_story_file(path: Path) -> Story:
    """
    Parse a story file's header and return a Story.
    Header is the lines between `# Story:` and the first `##` section.
    """
    filename = path.name
    match = STORY_FILENAME_RE.match(filename)
    if not match:
        raise SpecError(
            f"{path}: filename must match STORY-NNN-<kebab-slug>.md"
        )

    try:
        text = path.read_text(encoding="utf-8")
    except OSError as e:
        raise SpecError(f"{path}: cannot read file: {e}")

    lines = text.splitlines()
    if not lines:
        raise SpecError(f"{path}: file is empty")

    title: Optional[str] = None
    fields: dict[str, str] = {}
    in_header = False

    for raw in lines:
        line = raw.rstrip()

        if not in_header:
            title_match = STORY_TITLE_RE.match(line)
            if title_match:
                title = title_match.group(1).strip()
                in_header = True
            continue

        # Header ends at first ## section.
        if line.startswith("##"):
            break

        if not line.strip():
            continue

        field_match = HEADER_FIELD_RE.match(line)
        if not field_match:
            # Tolerate stray lines in the header; skip silently.
            continue

        key = field_match.group(1).strip()
        value = field_match.group(2).strip()
        fields[key] = value

    if title is None:
        raise SpecError(f"{path}: missing `# Story: <title>` line")

    for required in ("ID", "Status", "Feature"):
        if required not in fields:
            raise SpecError(f"{path}: missing required header field `{required}`")

    story_id = fields["ID"].strip()
    if not re.match(r"^STORY-\d+$", story_id):
        raise SpecError(
            f"{path}: ID `{story_id}` must match STORY-NNN format"
        )

    filename_id = f"STORY-{match.group(1)}"
    if filename_id != story_id:
        raise SpecError(
            f"{path}: filename ID `{filename_id}` does not match header ID `{story_id}`"
        )

    status = fields["Status"].strip()
    if status not in VALID_STATUSES:
        raise SpecError(
            f"{path}: invalid status `{status}`. Valid: {sorted(VALID_STATUSES)}"
        )

    feature = fields["Feature"].strip()
    if not feature:
        raise SpecError(f"{path}: Feature field is empty")

    expected_feature = path.parent.name
    if feature != expected_feature:
        raise SpecError(
            f"{path}: Feature `{feature}` does not match parent directory `{expected_feature}`"
        )

    depends_on = parse_list(fields.get("Depends on", ""))
    supersedes = parse_optional(fields.get("Supersedes", ""))
    superseded_by = parse_optional(fields.get("Superseded by", ""))

    for ref_id in depends_on + [r for r in (supersedes, superseded_by) if r]:
        if not re.match(r"^STORY-\d+$", ref_id):
            raise SpecError(
                f"{path}: referenced ID `{ref_id}` must match STORY-NNN format"
            )

    return Story(
        story_id=story_id,
        title=title,
        feature=feature,
        status=status,
        file=str(path),
        depends_on=depends_on,
        supersedes=supersedes,
        superseded_by=superseded_by,
    )


def discover_story_files(root: Path) -> list[Path]:
    """Return all STORY-*.md files under root, sorted by ID."""
    if not root.is_dir():
        return []

    files: list[Path] = []
    for path in root.rglob("STORY-*.md"):
        if path.is_file():
            files.append(path)

    def sort_key(p: Path) -> int:
        m = STORY_FILENAME_RE.match(p.name)
        return int(m.group(1)) if m else 0

    files.sort(key=sort_key)
    return files


# ---- Validation ----

def validate_stories(stories: list[Story]) -> None:
    """Check for duplicates, broken refs, asymmetric supersession, cycles."""
    by_id: dict[str, Story] = {}

    for story in stories:
        if story.id in by_id:
            existing = by_id[story.id]
            raise SpecError(
                f"duplicate story ID `{story.id}` in `{story.file}` and `{existing.file}`"
            )
        by_id[story.id] = story

    for story in stories:
        for dep_id in story.depends_on:
            if dep_id not in by_id:
                raise SpecError(
                    f"{story.file}: `{story.id}` depends on `{dep_id}` which does not exist"
                )
        if story.supersedes and story.supersedes not in by_id:
            raise SpecError(
                f"{story.file}: `{story.id}` supersedes `{story.supersedes}` which does not exist"
            )
        if story.superseded_by and story.superseded_by not in by_id:
            raise SpecError(
                f"{story.file}: `{story.id}` superseded by `{story.superseded_by}` which does not exist"
            )

    for story in stories:
        if story.supersedes:
            other = by_id[story.supersedes]
            if other.superseded_by != story.id:
                raise SpecError(
                    f"{story.file}: `{story.id}` supersedes `{other.id}`, "
                    f"but `{other.id}` does not list `Superseded by: {story.id}`"
                )
        if story.superseded_by:
            other = by_id[story.superseded_by]
            if other.supersedes != story.id:
                raise SpecError(
                    f"{story.file}: `{story.id}` is superseded by `{other.id}`, "
                    f"but `{other.id}` does not list `Supersedes: {story.id}`"
                )

    WHITE, GRAY, BLACK = 0, 1, 2
    color: dict[str, int] = {s.id: WHITE for s in stories}

    def visit(node_id: str, path: list[str]) -> None:
        color[node_id] = GRAY
        for next_id in by_id[node_id].depends_on:
            if color[next_id] == GRAY:
                cycle = " -> ".join(path + [next_id])
                raise SpecError(f"dependency cycle detected: {cycle}")
            if color[next_id] == WHITE:
                visit(next_id, path + [next_id])
        color[node_id] = BLACK

    for story in stories:
        if color[story.id] == WHITE:
            visit(story.id, [story.id])


# ---- Index building ----

def build_index(stories: list[Story]) -> dict:
    deps: dict[str, list[str]] = {}
    blocks: dict[str, list[str]] = defaultdict(list)
    by_status: dict[str, list[str]] = {s: [] for s in sorted(VALID_STATUSES)}
    by_feature: dict[str, list[str]] = defaultdict(list)

    for story in stories:
        if story.depends_on:
            deps[story.id] = list(story.depends_on)
            for dep in story.depends_on:
                blocks[dep].append(story.id)
        by_status[story.status].append(story.id)
        by_feature[story.feature].append(story.id)

    for key in blocks:
        blocks[key].sort()
    for key in by_feature:
        by_feature[key].sort()
    for key in by_status:
        by_status[key].sort()

    return {
        "stories": [s.to_dict() for s in stories],
        "deps": dict(sorted(deps.items())),
        "blocks": dict(sorted(blocks.items())),
        "by_status": by_status,
        "by_feature": dict(sorted(by_feature.items())),
    }


# ---- Atomic write ----

def write_atomic(path: Path, content: str) -> None:
    tmp = path.with_suffix(path.suffix + ".tmp")
    tmp.write_text(content, encoding="utf-8")
    os.replace(tmp, path)


# ---- Main ----

def main() -> int:
    parser = argparse.ArgumentParser(
        description="Rebuild specs/index.json from story files."
    )
    parser.add_argument(
        "--specs-dir",
        type=Path,
        default=SPECS_DIR,
        help="Path to specs directory (default: ./specs)",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Validate only; do not write index.json",
    )
    args = parser.parse_args()

    specs_dir = args.specs_dir
    features_dir = specs_dir / "features"
    index_path = specs_dir / "index.json"

    if not features_dir.exists():
        fail(f"features directory not found: {features_dir}")

    files = discover_story_files(features_dir)

    stories: list[Story] = []
    try:
        for path in files:
            stories.append(parse_story_file(path))
        validate_stories(stories)
    except SpecError as e:
        fail(str(e))

    index = build_index(stories)
    content = json.dumps(index, indent=2, ensure_ascii=False) + "\n"

    if args.check:
        print(f"regen-index: validated {len(stories)} stories (--check, not writing)")
        return 0

    write_atomic(index_path, content)
    print(f"regen-index: wrote {index_path} ({len(stories)} stories)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
````

After creating the file, run `chmod +x scripts/spec/regen-index`, then run `python3 scripts/spec/regen-index` once to create an initial empty `specs/index.json`.

---

## Step 7: Set up hooks

Hooks are configured in `.claude/settings.json` (or the equivalent path for this version of Claude Code). Set up these four hooks:

### Hook 1: Run related tests on source code edits

- **Trigger**: `PostToolUse` on Write/Edit when the target file is under project source directories (e.g., `src/`, `lib/`, `app/`). Adapt to project layout.
- **Action**: Run the test command scoped to the changed file. Detect the test runner from project config:
  - Node + Vitest: `vitest run --related <file>`
  - Node + Jest: `jest --findRelatedTests <file>`
  - Python + pytest with testmon: `pytest --testmon`
  - Python + pytest: run tests in the same module
  - Other: best-effort match, or log a warning and skip (do not block edits)

### Hook 2: Require full-suite pass before `pending-verification`

- **Trigger**: `PostToolUse` on Edit/Write to a story file when the new Status line is `pending-verification`.
- **Action**: Run the full test suite. If it fails, revert the status to `in-progress` and write a Verification note explaining "Full suite failed; cannot transition to pending-verification."

### Hook 3: Trigger verifier on `pending-verification`

- **Trigger**: Same trigger as Hook 2, but runs only after Hook 2 passes.
- **Action**: Invoke the `verifier` sub-agent with the story ID. If the story has `[visual]` AC, also invoke `ui-verifier`.

### Hook 4: Regenerate index on any story file change

- **Trigger**: `PostToolUse` on Edit/Write to any file under `specs/features/`.
- **Action**: Run `python3 scripts/spec/regen-index`.

### Optional: Pre-commit hook (git)

If a pre-commit framework is in use, add a hook that runs the full test suite and `python3 scripts/spec/regen-index --check`. Final safety net before code enters git history.

If the installed Claude Code version's hook configuration differs, adapt the syntax but preserve the trigger/action semantics. If hooks cannot be configured automatically, surface the configuration to the user with instructions.

---

## Step 8: Update or create `CLAUDE.md`

If `CLAUDE.md` exists at project root, append the section below. If not, create one with this content:

````markdown
# Working in this project

This project uses spec-driven development. Before writing or changing any code:

1. **Find or create the relevant story.** Check `specs/index.json` to see existing stories. If the work does not fit any existing story, ask the user to discuss requirements first — the `spec-author` skill will draft a story.

2. **Read the story in full** before implementing. Pay attention to AC and non-goals.

3. **Set the story status to `in-progress`** when you start work. The index auto-regenerates via hook.

4. **Write tests first for `[behavioral]` AC.** For each AC, write a failing test before implementing. Name tests `STORY-NNN AC-N: <description>`. Confirm tests fail for the right reason (not syntax errors or missing imports).

5. **Implement code until AC tests pass.** Refactor with tests green.

6. **When all AC are met**, run the full test suite. Once green, set the story status to `pending-verification`. The verifier (and ui-verifier if visual AC present) will be triggered automatically. Do not mark a story `done` yourself — only the verifier does that.

7. **If the verifier returns the story to `in-progress`** with notes, address the notes and re-submit.

8. **For changes not tied to a single story** (refactors, bug fixes across modules): make the change, then expect the verifier hook to re-check affected `done` stories. If it flags regressions, fix them before committing.

The full format and workflow are in `specs/README.md`. The skill that drafts stories is `spec-author`. The sub-agents that verify are `verifier` and `ui-verifier`.
````

---

## Step 9: Bootstrap verification

After all files are in place:

1. Run `python3 scripts/spec/regen-index` to create an initial empty `specs/index.json`.
2. Verify the skill is discoverable. The `spec-author` skill should appear in available skills.
3. Verify the sub-agents are discoverable. `verifier` (and `ui-verifier` if installed) should appear.
4. Test hooks fire on a no-op edit: create a temp story file, edit it, confirm `regen-index` runs and updates `index.json`. Then delete the temp file and re-run regen.
5. Detect the project's test runner and confirm Hook 1 can invoke it. If detection fails, surface this to the user.
6. Detect whether the project has a UI and whether a browser MCP server is connected. If yes, install `ui-verifier`. If no, skip and tell the user.

---

## Step 10: Report back to the user

Once setup is complete, report:

- What was created (folders, files, scripts, hooks).
- Which sub-agents were installed (verifier always; ui-verifier conditionally).
- How to start the first story: just describe a feature in plain language; the `spec-author` skill will pick it up.
- Project-specific adaptations made: test runner detected, source directories identified, dev server URL (if found), etc.
- Anything that could not be set up automatically and needs the user's input.

---

## Cast at a glance

- **Main agent** — implements code and tests.
- **`spec-author` skill** — drafts story files from your plain-language input.
- **`verifier` sub-agent** — judges behavioral AC; only authority that can mark `done`; also handles regression checks on changed code.
- **`ui-verifier` sub-agent** — judges visual AC using browser MCP (only if project has a UI).
- **`regen-index` Python script** — rebuilds `specs/index.json`.

That is the entire system. Two sub-agents (three with ui-verifier), one skill, one script.
