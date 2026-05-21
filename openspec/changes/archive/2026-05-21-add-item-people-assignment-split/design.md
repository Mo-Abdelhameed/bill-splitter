## Context

The app already captures a receipt image (STORY-003) and extracts items via an OCR/LLM backend (STORY-002), plus a basic people-entry screen (STORY-001). Today the extraction returns a flat list of items; there is no per-diner assignment, and tax/service are either bundled into items or returned as opaque numbers. The bill-split flow needs to be the connective tissue between these existing pieces: take the extracted receipt + diners, let the user assign who-had-what, and produce per-diner totals that correctly allocate tax and service.

The codebase is split into a Flutter mobile frontend and a FastAPI Python backend. Receipt extraction lives server-side (LLM call); diner state and assignment UX naturally live client-side because they are interactive.

## Goals / Non-Goals

**Goals:**
- Many-to-many diner↔item assignment with live, editable UI.
- Deterministic, transparent per-diner totals that always sum (to within rounding) to the bill grand total.
- Automatic detection of tax and service lines from the receipt, returned as structured fields, not regular items.
- Proportional allocation of tax and service to each diner based on that diner's pre-tax item subtotal.
- Work fully offline once the receipt is extracted (assignment + totals are local computation).

**Non-Goals:**
- Settlement/payment (Venmo, Splitwise integration) — out of scope; we just show totals.
- Multi-bill sessions or history persistence beyond the current session.
- Tip entry/override UI — service charge is taken from the receipt only; user-added tip is a future change.
- Currency conversion or multi-currency receipts.
- Smart suggestions ("looks like Alice always gets the salad") — purely manual assignment.

## Decisions

### Decision 1: Equal-share split per item, with explicit assignment set

**Choice:** When N diners are assigned to one item, each owes `item.price / N`. No weights, no "I only had a bite" fractional shares in v1.

**Why:** Covers the overwhelming majority of restaurant scenarios. Weighted shares add UI complexity (sliders, fraction inputs) and rounding edge cases for a marginal use case.

**Alternatives considered:**
- Per-diner weight (e.g., 0.5/1.0/1.5): rejected for v1 UX complexity. Data model leaves room (`share_weight` field, default 1.0) so we can add later without a migration.
- Quantity-based split (item with `quantity: 2` auto-splits as two units): rejected because the receipt often groups identical orders into one line; we'd need a separate "split this line into N units" affordance, which is more UI than equal-share.

### Decision 2: Proportional tax/service allocation by pre-tax subtotal

**Choice:** Each diner's tax share = `tax_total * (diner_subtotal / sum_of_all_diner_subtotals)`. Same formula for service.

**Why:** Matches how restaurants compute it (tax is a percentage of the pre-tax bill, and each diner's "pre-tax bill" is the sum of their item shares). It's also fair: the person who ordered a $40 steak pays more tax than the person who ordered a $10 salad.

**Alternatives considered:**
- Equal split of tax/service across diners: simpler but unfair when orders differ in size; rejected.
- Tax as a flat percentage applied to each diner's subtotal (recompute the rate): produces the same result as proportional only when all items have the same tax rate; if the receipt's effective tax differs from a clean percentage (e.g., tax-exempt items, rounding), the proportional method is correct because it preserves the bill's actual tax total.

### Decision 3: Tax/service detection happens server-side, returned as structured fields

**Choice:** The receipt-extraction endpoint returns:
```
{
  "items": [{name, price, quantity}, ...],
  "charges": {
    "tax": <number | null>,
    "service": <number | null>
  },
  "subtotal": <number | null>,
  "total": <number | null>
}
```
The LLM extraction prompt is updated to classify lines as item vs. tax vs. service vs. discount/other.

**Why:** The LLM already sees the full receipt context; client-side heuristics (regex on "tax", "TVA", "service", "gratuity", "VAT") are brittle across languages and formats. Centralizing detection means the mobile client just trusts the response.

**Alternatives considered:**
- Client-side heuristic detection: rejected — too many edge cases (i18n, abbreviations, percentages embedded in line text).
- A separate `/classify-charges` endpoint after extraction: rejected — extra round-trip for no benefit; the model has everything it needs in one pass.

### Decision 4: Totals computed client-side

**Choice:** The Flutter app computes per-diner totals from the assignment map and the charges field. No backend endpoint for totals.

**Why:** The computation is trivial arithmetic and the assignment state lives in the client. A server round-trip per edit would harm UX. Determinism is preserved by keeping the formula in one place (a pure Dart function).

**Alternatives considered:**
- Server-side `/compute-totals`: rejected — adds latency and offline failure modes for no algorithmic benefit.

### Decision 5: Unassigned items are surfaced, not silently dropped

**Choice:** The summary screen shows a banner if any items are unassigned, and refuses to declare the split "complete" until every item has at least one diner. Unassigned items are NOT distributed across all diners by default.

**Why:** Silent distribution leads to wrong totals when the user simply hasn't finished assigning. Explicit feedback is safer.

**Alternatives considered:**
- Auto-assign unassigned items to all diners: rejected — masks user error.
- Allow "house pays" / unassigned bucket: deferred; might add as opt-in later.

### Decision 6: Rounding strategy — bankers' rounding to cents, with a residual line

**Choice:** Each diner's total is rounded to the nearest cent (banker's rounding / half-to-even). If the sum of rounded diner totals differs from the bill grand total by `±1 cent × N`, the residual is shown as a small "rounding" note in the summary; we do not silently inflate or deflate any single diner.

**Why:** Floating-point and percentage-based allocation always produce sub-cent residuals; hiding them causes "the totals don't add up" complaints. A visible residual is honest.

## Risks / Trade-offs

- **[Risk] LLM mis-classifies a discount or tip-included line as a regular item** → Mitigation: include a "review charges" step in the summary screen showing detected tax/service values; user can correct them inline before finalizing.
- **[Risk] Equal-share assumption frustrates groups with mixed appetites** → Mitigation: data model carries `share_weight` field from day one; add UI in a follow-up change without breaking persisted state.
- **[Risk] Floating-point arithmetic causes inconsistent totals across platforms** → Mitigation: use integer cents (smallest currency unit) throughout the computation; convert to display strings only at the UI layer.
- **[Risk] User adds/removes a diner after assigning items** → Mitigation: assignments reference diner IDs; removing a diner cascades to remove their entries from each item's assignment set, and the UI re-renders totals immediately.
- **[Trade-off] No persistence between sessions in v1** → Acceptable because the bill-split workflow is typically completed in one sitting; persistence can be layered in later without changing the computation.
