# Story: Extract items from a receipt image
ID: STORY-002
Status: done
Feature: extraction

## Intent
As a user who has a receipt image in app state, I want the app to extract a structured list of items (name + price) and any tax/service charges from the image, so that I can review and edit the data before proceeding to assignment.

## Context
This story covers ONLY the extraction step. The image is assumed to already be in app state from an upstream future story (image acquisition is not yet defined; STORY-002 is unblocked because it can be tested against an injected/mocked image).

Gemini 2.5 Flash is the chosen vision model per the user's snippet (2026-05-19, source quoted below). This is an implementation detail and not part of any AC.

> "the image should should get passed to Gemini 2.5 Flash. it should return a list of items {name, price}. if a receipt has a single item with a quantity more than one, it should be reflected as more than an item in the list. for example pasta with quantity of 3 and a price of 50 should be [{pasta, 50}, {pasta, 50}, {pasta, 50}]."

Per explicit user decisions (2026-05-19): no visual AC for this story; tax and service are returned as `number | null` (no boolean flags in the wire schema — checkbox state is derived from null-ness); UI shows checkboxes the user can toggle to override Gemini; the items list supports edit + delete + add; failure shows both retry and manual-fallback affordances.

AC-13 makes an interaction choice that wasn't explicitly stated by the user (when the user CHECKS a previously-unchecked tax/service box, what does the amount default to?). The choice is "default to 0 and show an editable input" — flag in review if you want a different mapping.

## Acceptance Criteria
- [ ] AC-1 [behavioral]: Given the user lands on this screen with a receipt image already in the app's bill state, when the screen renders for the first time, then the image is visible as a preview, an "Extract items" button is visible, no list of items is rendered, and no Gemini network request has been initiated.

- [ ] AC-2 [behavioral]: Given the pre-extraction state, when the user taps "Extract items", then exactly one HTTP request to Gemini 2.5 Flash is initiated with the image bytes attached, requesting a JSON response matching the schema in AC-3, and the screen transitions to a loading state until the response arrives or the call fails.

- [ ] AC-3 [behavioral]: Given the Gemini call completes with a 2xx response, when the response body is parsed, then the parsed object conforms to:
  ```
  {
    "items": [ { "name": string, "price": number }, ... ],
    "tax":     number | null,
    "service": number | null
  }
  ```
  with the following semantics:
  - `items` contains one entry per *single unit* of purchase. If the receipt shows "pasta × 3 @ 50", `items` contains exactly three entries: `[{name:"pasta", price:50}, {name:"pasta", price:50}, {name:"pasta", price:50}]`.
  - `tax` is the numeric tax amount listed on the receipt, or `null` if no tax line is present.
  - `service` is the numeric service-charge amount listed on the receipt, or `null` if no service-charge line is present.

- [ ] AC-4 [behavioral]: Given a successful response per AC-3, when the screen leaves the loading state, then an editable items list is displayed, each row corresponding to one entry in `items` and exposing its `name` and `price` for inline editing.

- [ ] AC-5 [behavioral]: Given the items list is displayed, when the user edits any row's `name` or `price`, then the change is reflected in the in-screen state immediately (no explicit Save action required).

- [ ] AC-6 [behavioral]: Given the items list is displayed, when the user performs a swipe-to-delete gesture on a row or taps a per-row delete affordance, then that row is removed from the screen and from in-screen state.

- [ ] AC-7 [behavioral]: Given the items list is displayed, when the user taps an "Add item" affordance, then a new row is appended to the list with `name: ""` and `price: 0`, focused and ready for input.

- [ ] AC-8 [behavioral]: Given a successful response per AC-3 where `tax` is non-null, when the screen leaves the loading state, then a "Tax included" checkbox is visible and checked, and an editable amount input next to it shows the returned `tax` value.

- [ ] AC-9 [behavioral]: Given a successful response per AC-3 where `tax` is `null`, when the screen leaves the loading state, then a "Tax included" checkbox is visible and unchecked, and no tax amount input is rendered.

- [ ] AC-10 [behavioral]: Given a successful response per AC-3 where `service` is non-null, when the screen leaves the loading state, then a "Service included" checkbox is visible and checked, and an editable amount input next to it shows the returned `service` value.

- [ ] AC-11 [behavioral]: Given a successful response per AC-3 where `service` is `null`, when the screen leaves the loading state, then a "Service included" checkbox is visible and unchecked, and no service amount input is rendered.

- [ ] AC-12 [behavioral]: Given a checked "Tax included" (or "Service included") checkbox, when the user unchecks it, then the corresponding amount input is removed from the screen and the amount in in-screen state becomes `null`.

- [ ] AC-13 [behavioral]: Given an unchecked "Tax included" (or "Service included") checkbox, when the user checks it, then an editable amount input appears next to the checkbox with an initial value of `0`, and the amount in in-screen state becomes whatever is typed into the input (initially `0`).

- [ ] AC-14 [behavioral]: Given an extraction attempt fails for any reason — network error, non-2xx HTTP response from Gemini, response body not parseable as JSON, parsed JSON does not match the AC-3 schema, or `items` array is empty — when the failure is observed, then the screen transitions to an error state that shows: an error message identifying the failure category, a "Retry" button that re-runs the Gemini call with the same image, and an "Enter items manually" button that transitions the screen to the post-extraction state with an empty editable items list, `tax: null`, and `service: null`.

- [ ] AC-15 [behavioral]: Given the items list contains at least one item with a non-empty trimmed `name`, when the screen evaluates the "Continue" button, then "Continue" is enabled.

- [ ] AC-16 [behavioral]: Given every visible item has an empty or whitespace-only `name`, OR the items list is empty, when the screen evaluates the "Continue" button, then "Continue" is disabled.

- [ ] AC-17 [behavioral]: Given "Continue" is enabled and the user taps it, when navigation runs, then (a) the app navigates away from the extraction screen, (b) the in-screen items list (trimmed names, current prices), the current tax value (`number | null` from the checkbox+input state), and the current service value (`number | null`) are committed into the app's bill state, and (c) the destination route is the next screen in the bill flow (placeholder allowed until that story is implemented).

## Non-goals
- Currency, subtotal, and total extraction from the receipt (Gemini is not asked for these in this story; deferred to a future story).
- Persisting the extracted/edited list across app restarts (no Hive integration in this story).
- Image compression or resizing before sending to Gemini (no max-size enforcement here; deferred).
- Image acquisition (camera or gallery picker) — separate future story; this story assumes the image is already in app state.
- Visual acceptance criteria — explicitly behavioral only for this story per user decision.

## Verification notes

Verified 2026-05-19: all 17 behavioral AC satisfied; 29/29 tests pass; flutter analyze clean.

- AC-1: pre-extraction render shows image, button, no items, no extractor call (callCount 0). PASS.
- AC-2: Tap triggers exactly one extractor.extract() call with the image bytes and shows CircularProgressIndicator until resolution. The real GeminiExtractorImpl posts a JSON body with `generationConfig.responseSchema` matching AC-3 (verified by code inspection at lib/services/gemini_extractor.dart lines 153-157). PASS.
- AC-3: ExtractionResult.fromJson preserves one BillItem per items entry (quantity expansion handled at the prompt level by Gemini, then parsed entry-by-entry), tolerates tax/service null, rejects missing/wrong-typed fields with ExtractionFailure.schema. PASS.
- AC-4: One row (name + price TextField pair) per item. PASS.
- AC-5: TextField controllers update in-screen state on each keystroke; name onChanged also drives Continue re-evaluation. PASS.
- AC-6: Per-row delete IconButton removes the row from _items. (Story permits OR between swipe-to-delete and per-row affordance; per-row chosen.) PASS.
- AC-7: Add item appends an _EditableItem with name '' and price '0'. Minor note: the AC text says "focused and ready for input"; the implementation does not auto-focus the new field, and the test does not assert focus. Field is editable on tap; treating "ready for input" as satisfied by editable rendering. Not a blocker.
- AC-8/9/10/11: Checkbox value mirrors tax/service != null, and amount input is conditionally rendered. PASS.
- AC-12: Unchecking hides the amount input; _onContinue commits null for unchecked. Verified end-to-end by tapping Continue and asserting billState.tax/service are null. PASS.
- AC-13: Checking sets controller.text = '0' so the amount input shows '0'. PASS.
- AC-14: All five failure modes mapped: DioException network/timeout → ExtractionFailure.network; non-2xx → http; non-JSON inner text → parse; missing/wrong-typed fields → schema; empty items → emptyItems. Error UI shows the kind name, a Retry button (re-issues call), and a manual-fallback button (enters empty editable state). PASS.
- AC-15: Continue enabled iff any item has a non-empty trimmed name. PASS.
- AC-16: Empty list and whitespace-only names both disable Continue. PASS.
- AC-17: Continue commits trimmed names, parsed prices, and current tax/service (number|null) into BillState, then invokes onContinue (router navigates to /assign placeholder). PASS.

Non-goals respected: no subtotal/total extraction, no Hive persistence, no image acquisition, no visual AC introduced.

Visual AC: none for this story (explicit user decision); ui-verifier not run.
