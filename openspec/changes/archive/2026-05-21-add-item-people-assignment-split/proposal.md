## Why

Splitting a restaurant bill is tedious and error-prone: someone has to read the receipt aloud, track who ordered what, and manually pro-rate tax and service charges per person. We want a single mobile flow where a user photographs the bill, assigns diners to items (many-to-many), and instantly sees what each person owes including their fair share of tax and service.

## What Changes

- Add a bill-splitting flow that takes an OCR'd receipt (items, tax, service) and lets users add diners and assign them to items.
- Support many-to-many assignment: an item can be split across multiple diners and a diner can be on multiple items.
- Automatically detect tax and service-charge lines from the receipt and exclude them from the per-item assignment pool.
- Compute each diner's total as: (sum of their shares of assigned item subtotals) + (their proportional share of tax) + (their proportional share of service), where proportions are based on each diner's pre-tax subtotal.
- Render a per-diner summary with itemized breakdown and grand total.

## Capabilities

### New Capabilities
- `bill-assignment`: Lets users define the set of diners on a bill and assign them to items in a many-to-many relationship, with live editing of who is on which item.
- `bill-totals`: Computes per-diner totals from item assignments, including proportional allocation of detected tax and service charges, and exposes the breakdown for display.
- `receipt-charges-detection`: Identifies tax and service-charge lines in an extracted receipt and separates them from regular items so they are not double-counted during assignment.

### Modified Capabilities
<!-- No existing capability specs in openspec/specs/ yet; nothing to modify. -->

## Impact

- Frontend (Flutter): new assignment screen, diners list editor, totals/summary screen, and state management for assignments.
- Backend (FastAPI): receipt-extraction response must surface tax/service lines as a distinct, structured field; new endpoint (or client-side computation) for per-diner totals.
- Data model: introduces `Diner`, `Assignment` (diner ↔ item with optional share weight), and structured `Charges` (tax, service) alongside existing `ReceiptItem`.
- No external dependencies expected beyond existing OCR/LLM pipeline used for receipt extraction.
