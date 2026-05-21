## 0. Scaffolding (fresh build)

- [x] 0.1 Scaffold `backend/` (FastAPI app with `app/main.py`, `pyproject.toml`, tests dir).
- [x] 0.2 Scaffold `frontend/` (Flutter app via `flutter create`, restructure lib/ for feature folders).
- [x] 0.3 Wire root Makefile targets (test, analyze, run) to the new dirs.

## 1. Backend: structured charges in extraction response

- [x] 1.1 Define receipt-extraction Pydantic response model with `items[]`, `charges: {tax, service}`, `subtotal`, and `total` fields (nullable numbers).
- [x] 1.2 Implement LLM extraction call (Gemini) with a prompt that classifies each line as item, tax, service, discount, or other; populates the new `charges` fields. Pluggable so it can be stubbed in tests.
- [x] 1.3 Ensure tax/service lines are excluded from the returned `items` list.
- [x] 1.4 Add backend unit tests covering: tax+service present, tax only, neither, non-English labels (VAT, TVA, Gratuity).
- [x] 1.5 API documented via FastAPI auto-docs + example response.

## 2. Frontend: data models

- [x] 2.1 Add `Diner` model (id, name) in the Flutter app.
- [x] 2.2 Add `Assignment` model or assignment map keyed by item id → set of diner ids.
- [x] 2.3 Extend the receipt response model on the client to parse the new `charges` field.
- [x] 2.4 Add a `BillTotals` value object (per-diner subtotal/tax_share/service_share/grand_total + bill grand total + rounding residual).

## 3. Frontend: totals computation

- [x] 3.1 Implement a pure Dart `computeTotals(items, assignments, charges)` function using integer cents to avoid float drift.
- [x] 3.2 Implement proportional tax/service allocation by per-diner subtotal share.
- [x] 3.3 Apply banker's rounding to per-diner totals and compute the rounding residual.
- [x] 3.4 Unit-test the computation against the scenarios in `specs/bill-totals/spec.md` (equal split, multi-item diner, zero tax, zero service, residual surfacing).

## 4. Frontend: diners screen

- [x] 4.1 Build/extend the diners screen so the user can add, rename, and remove diners.
- [x] 4.2 Validate non-empty names; show inline error for empty/whitespace.
- [x] 4.3 On diner removal, cascade-remove that diner from every item's assignment set.

## 4b. Frontend: capture + extract entry

- [x] 4b.1 Build a capture screen that lets the user pick or photograph a receipt image and POSTs it to the backend `/extract` endpoint.
- [x] 4b.2 Show a loading / error state during extraction; show a stub/mock option when no backend key is configured.

## 5. Frontend: assignment screen

- [x] 5.1 Build the assignment screen listing each receipt item with selectable diner chips/checkboxes.
- [x] 5.2 Exclude tax/service charges from the assignable items list.
- [x] 5.3 Support many-to-many toggle: any number of diners can be selected per item; any diner can appear on multiple items.
- [x] 5.4 Show a visible indicator (badge/banner) listing items with zero assignees.
- [x] 5.5 Persist assignment state in shared bill-session state so navigation does not lose it.

## 6. Frontend: summary screen

- [x] 6.1 Build the summary screen showing per-diner breakdown: subtotal, tax share, service share, grand total.
- [x] 6.2 Show the bill grand total and the rounding residual (if non-zero) as a labeled note.
- [x] 6.3 Show editable fields for tax and service so the user can correct mis-detected values; recompute totals on edit.
- [x] 6.4 Disable/guard the "finalize" action while any item is unassigned; show which items are blocking.

## 7. Wiring & navigation

- [x] 7.1 Wire the flow: capture → extract → diners → assignment → summary, passing the receipt + diners state.
- [x] 7.2 Ensure back-navigation preserves diners and assignments within the session.

## 8. Verification

- [x] 8.1 Add a widget test for the assignment screen covering many-to-many toggling and unassigned-items banner.
- [x] 8.2 Add a widget test for the summary screen covering per-diner totals and the tax/service override path.
- [ ] 8.3 Manual run on iOS simulator and Android emulator (`make frontend-run-ios`, `make frontend-run-android`) with a real receipt photo end-to-end.
- [x] 8.4 `make test` and `make analyze` pass.
