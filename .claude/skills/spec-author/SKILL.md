---
name: spec-author
description: Use this skill when the user wants to define a new feature, requirement, or user story for this project. Trigger phrases include "I want to add a feature", "let's spec out", "I need a story for", "draft a story", "new requirement", or any time the user describes desired behavior in plain language and the project uses spec-driven development. The skill drafts a properly formatted story file, confirms acceptance criteria with the user, and saves it to the right feature folder.
---

# spec-author

You are drafting a user story for a spec-driven project. The format and rules are defined in `specs/README.md` — read it before drafting if you have not this session.

## Process

1. **Read `specs/README.md`** for the current format and rules.
2. **Read `specs/index.json`** to determine the next story ID and see existing features.
3. **Ask the user how they want to provide the spec material**, before doing anything else. Offer two modes and let them pick:

   **(a) Source-document mode** — the user points you at a file or section (e.g., `specs/docs/bill_split_plan.md`, a markdown brief, an issue). You read it and use ONLY what is written there, plus anything the user adds in chat.

   **(b) Interactive chat mode** — you interview the user with grouped questions about whichever pieces are missing from their description.

4. **Gather the story material** using the chosen mode. The pieces to cover:
   - Who is the user (role/type)?
   - What capability do they want?
   - Why — what outcome?
   - What does "done" look like? (every AC must trace to an answer here)
   - What is explicitly out of scope? (every non-goal must trace to an answer here)
   - Does this depend on or supersede an existing story?
   - Are there any visual or responsive requirements? (if yes: which viewport, what element positions, sizes, states)
   - What edge cases or error states does the user care about (validation rules, empty states, failure modes)?

   **Core rule — applies in every mode, every time:** every line of the eventual draft must trace to something explicitly written in the source, something the user said in chat, or an explicit answer to a question you asked. Never invent, never default, never assume. **The moment you sense a gap — a missing piece, an ambiguous statement, a detail the source does not cover — stop drafting and ask the user, regardless of which mode you are in.** In source-document mode, when the source is silent on something needed for AC or non-goals, ask immediately rather than guess.

   Other rules:
   - **Ask only what is missing.** Read input/source carefully first; do not re-ask things already stated.
   - **Group questions when possible.** Batch related gaps into one round rather than ping-pong, but do NOT defer asking just to keep a batch tidy — if a single critical gap shows up mid-draft, stop and ask right then.
   - **Do not pre-fill answers.** Asking "should this require email verification?" is fine. Drafting "no email verification" into non-goals because that is the common default is NOT fine.
   - **If the user defers a decision** ("use your judgment", "you decide"), record the explicit deferral in the story's Context section. Do not make silent decisions.

5. **Determine the feature folder.** Match against existing folders in `specs/features/`. If none fit, propose a new one and confirm with the user.

6. **Draft the story file** following the format in `specs/README.md`:
   - Rewrite AC in Given/When/Then form so they are testable.
   - Tag each AC as `[behavioral]` (default) or `[visual @viewport]`.
   - For visual AC, push for precision ("button width fills container at 375px, height ≥44px") over vagueness ("looks clean on mobile").
   - Include only non-goals the user explicitly stated or confirmed when asked. Do not infer non-goals from context; if you think a non-goal is likely, ask the user before adding it.
   - Set `Status: draft`.

7. **Show the draft to the user** for confirmation before saving. Make edits as requested.

8. **Save the file** to `specs/features/<feature>/STORY-NNN-<slug>.md`. Use a kebab-case slug derived from the title.

9. **Run `python3 scripts/spec/regen-index`** to update `specs/index.json`.

10. **Confirm to the user** that the story is saved. Show the ID and path.

## Important behaviors

- **You write the formatted story; the user writes the intent.** Do not invent acceptance criteria the user did not ask for. Do not expand scope. If you are unsure whether something belongs in the story, ask.
- **AC must be observable.** "The system is fast" is not testable. "Response returns in under 200ms at p95" is.
- **One story per user-facing capability.** If the user describes three loosely related capabilities, propose splitting into three stories.
- **Do not fill `Verification notes`.** That section is for the verifier or for the author flagging something specific. Leave empty by default.
- **Do not write code or tests in this skill.** Only the story file. Implementation comes later via the main agent.
