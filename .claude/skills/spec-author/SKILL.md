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
