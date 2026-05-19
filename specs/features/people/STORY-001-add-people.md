# Story: Add people to a new bill split
ID: STORY-001
Status: done
Feature: people

## Intent
As a user starting a new bill split, I want to enter the names of every person sharing the bill, so that I can later assign receipt items to them.

## Context
This is the first screen the user sees when they open the app. Per the user's decision (2026-05-19), the people-entry screen comes BEFORE the receipt-capture screen, overriding the original phase order in `specs/docs/bill_split_plan.md` (Phase 2 Capture was originally first; Phase 4 People comes later). `bill_split_plan.md` should be updated separately to reflect this revised flow.

Visual layout details for this story were explicitly deferred by the user (2026-05-19) to be proposed by the implementer; the user reviewed and approved them as written below.

AC-7 references the Capture/photo screen, which is the subject of a future story. For this story's verification, a placeholder Capture route is acceptable as long as navigation leaves the names screen and the names list is carried forward into bill state.

## Acceptance Criteria
- [ ] AC-1 [behavioral]: Given the user launches the app fresh, when the first screen renders, then exactly one empty name text field is visible, an "Add another" button with a `+` icon is visible below it, and the "Continue" button is visible and disabled.

- [ ] AC-2 [behavioral]: Given the screen is in any state, when the user taps "Add another", then a new empty name text field appears below the existing fields, and that new field has an "✕" remove button beside it.

- [ ] AC-3 [behavioral]: Given a name field was added via "Add another" (and therefore has an "✕" remove button), when the user taps the "✕" beside it, then that field is removed from the screen. The original (first) name field never has an "✕" and can never be removed; the screen always contains at least one name field.

- [ ] AC-4 [behavioral]: Given any state of the visible name fields, when the screen re-evaluates the "Continue" button, then "Continue" is enabled if and only if at least two name fields contain non-empty text after trimming surrounding whitespace. Duplicate names do NOT disable "Continue" — the duplicate check runs only on Continue tap (see AC-5).

- [ ] AC-5 [behavioral]: Given the user taps "Continue" and two or more visible name fields contain values that match case-insensitively after trimming, when the duplicate check runs, then a visible duplicate-name indicator appears next to each conflicting field AND navigation does NOT occur AND `billState.people` is not modified.

- [ ] AC-6 [behavioral]: Given any name field is empty or whitespace-only, when the screen re-evaluates "Continue", then "Continue" is disabled if fewer than two fields are non-empty (after trimming), with no inline error shown for empty fields. Duplicate-name indicators are not shown during typing — only after a Continue tap reveals them (per AC-5).

- [ ] AC-7 [behavioral]: Given "Continue" is enabled, the user taps it, AND no two trimmed non-empty names match case-insensitively, when navigation runs, then (a) the app navigates away from the names screen, (b) the trimmed non-empty names list is committed into the app's bill state in the order shown on screen, and (c) the destination route is the Capture/photo screen (placeholder allowed until that story is implemented).

- [ ] AC-8 [visual @mobile]: At the iPhone 17 simulator and the Medium_Phone Android emulator, the screen renders these elements in this vertical order from top to bottom, all visible without scrolling on the default screen height:
  1. A screen title "Who's splitting?", left-aligned, with at least 16 logical pixels of padding above and below.
  2. The first name text field with placeholder "Enter name" and no "✕" button.
  3. Zero or more additional name text fields below the first, each with placeholder "Enter name" and a 24-logical-pixel "✕" icon button on the field's trailing edge.
  4. An "Add another" text-with-leading-`+`-icon button, left-aligned, immediately below the last name field.
  5. A "Continue" primary button at the bottom of the screen, filling the full content width with minimum height 48 logical pixels and the app's primary theme color. When disabled, it renders at 40% opacity.
  6. The duplicate-name indicator (when AC-5 applies): a 14-pixel red text "Duplicate name" appearing immediately below each duplicated field, with 4 logical pixels of vertical spacing above the text.

## Non-goals
- Person colors / avatars (deferred from the plan's Phase 4).
- Recent-names quick suggestions surfaced from past bills (deferred from the plan's Phase 4).
- Reordering names via drag-to-reorder.
- Validation beyond empty and duplicate (no max length, no banned characters, no profanity filtering).

## Verification notes
2026-05-19 verifier: PASS (initial). All 7 behavioral AC (AC-1..AC-7) satisfied by `lib/screens/people_screen.dart` + `lib/state/bill_state.dart` + `lib/router.dart`. Full `flutter test` suite passed (8/8) and `flutter analyze` reported zero issues. AC-8 [visual @mobile] not checked by this verifier — delegated to ui-verifier.

2026-05-19 amendment: AC-4, AC-5, AC-6, AC-7 were reworded by the user to defer duplicate-name detection from typing time to "Continue" tap time. The user reported that the original behavior fired duplicate indicators while typing a longer name that has a shorter existing name as a substring (e.g., typing "Sara" then "Sarah" briefly produces the "Sara" duplicate before "h" is appended). Status reverted to `in-progress`; tests and implementation will be updated to match the new AC, then re-verified.

2026-05-19 verifier (re-verification post-amendment): PASS. All 7 behavioral AC satisfied under the amended semantics. `_canContinue` no longer includes the duplicate check (AC-4). `_onContinue()` computes duplicates and short-circuits (no navigation, `billState.people` unmodified) when duplicates exist; otherwise commits trimmed non-empty names in order and navigates (AC-5, AC-7). `_duplicateNamesLower` is empty by construction during typing and cleared on every `onChanged`/`_addField`/`_removeField`, so the indicator never appears during typing, including the "Sara" → "Sarah" substring case (AC-6, explicitly covered by the AC-6 test at lines 189-193). AC-1/AC-2/AC-3 unchanged and still pass. Full `flutter test` suite passed (42/42) and `flutter analyze` reported zero issues. AC-8 [visual @mobile] not checked by this verifier — delegated to ui-verifier.
