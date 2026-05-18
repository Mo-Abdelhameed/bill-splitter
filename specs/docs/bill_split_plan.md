# Bill Split — Flutter App Implementation Plan

A Flutter app for iOS and Android. Users photograph a restaurant receipt, the app extracts line items via a vision LLM, the user assigns items to people via drag-and-drop (or tap-to-toggle), and gets per-person totals with locale-aware service charge, tax, and tip handling.

Primary market: Egypt. Locale defaults assume EGP currency, 12% service charge often pre-included, 14% VAT often pre-included, and optional 5–10% additional cash tip. Locale should be overridable so the app generalizes to other regions later.

---

## Tech Stack

- **Framework**: Flutter (latest stable), Dart
- **State management**: Riverpod (`flutter_riverpod`, `riverpod_annotation`, `riverpod_generator`)
- **Image capture**: `image_picker`
- **HTTP**: `dio`
- **Vision extraction**: Gemini 2.5 Flash via REST API (recommended — cheap, multimodal, native JSON mode). Fallback options: Claude Sonnet 4.5 vision via Anthropic API, or `gpt-4o-mini`.
- **Local persistence**: Hive (`hive`, `hive_flutter`) for bill history
- **Drag and drop**: Flutter built-in `Draggable` + `DragTarget`
- **Sharing**: `share_plus`
- **Env vars**: `flutter_dotenv` (for API key)
- **Localization**: Flutter `intl` + ARB files (English + Arabic, full RTL support)

---

## Data Model

```dart
class Bill {
  final String id;
  final DateTime createdAt;
  final String? imagePath;
  final List<BillItem> items;
  final List<Person> people;
  final bool serviceIncluded;       // user toggle
  final double serviceRate;         // default 0.12
  final bool taxIncluded;           // user toggle
  final double taxRate;             // default 0.14 (Egypt VAT)
  final double additionalTipPercent;// 0–25, default 0
  final String currency;            // ISO 4217, e.g. "EGP"
}

class BillItem {
  final String id;
  final String name;
  final double price;               // per-unit
  final int quantity;
  final List<String> assignedPersonIds; // many-to-many
}

class Person {
  final String id;
  final String name;
  final Color color;
}
```

**Splitting rule for MVP**: when N people share an item, the cost splits equally among them. Weighted splits are out of scope.

---

## Screens and Flow

### 1. Capture / Upload
- Two CTAs: "Take Photo" and "Pick from Gallery"
- After selection: show preview thumbnail + "Extract items" primary button
- Loading state during extraction call (skeleton list)
- On failure: error toast + button to "Enter items manually" (drops user into screen 2 with empty list)

### 2. Review Extracted Items
- List of editable rows: name (text field) + price (numeric field) + quantity stepper
- Swipe-to-delete on each row
- "Add item manually" FAB
- "Continue" CTA bottom
- Validation: non-empty name, positive price, quantity ≥ 1
- Always treat extraction output as a draft — never block edits

### 3. People
- Chip-based input: type name, hit Enter, chip appears with auto-assigned color from an 8-color palette
- Quick chips for recent names (from Hive history)
- Continue when ≥ 1 person added

### 4. Assignment (hardest screen)
- Items list with each item showing assigned-person avatar bubbles
- Two interaction modes (build both):
  - **Tap mode**: tap item → modal with a checkbox per person → toggle assignments. More reliable on small screens.
  - **Drag mode**: drag a person chip from a bottom strip onto an item to assign. Drag onto an already-assigned item to unassign.
- Per-item indicator showing the split count ("÷ 3" next to shared items)
- Warning banner if any item has zero assignees; prevent advancing until resolved (or explicit "split unassigned equally among all" button)

### 5. Configuration
Compact panel above the result:
- Checkbox: "Service already included" (default ON)
  - If unchecked: numeric input for service rate, default 12%
- Checkbox: "Tax already included" (default ON)
  - If unchecked: numeric input for tax rate, default 14%
- Slider: "Additional tip" 0–25%, default 0
- Toggle: round per-person total to nearest 0.5 / 1 / 5 EGP (cash convenience)

### 6. Result
Per-person cards:
- Name + color
- List of assigned items with each item's share
- Subtotal (their share of items)
- Service share
- Tax share
- Tip share
- **Total** (large, bold)
- "Copy" button per person (formatted summary text)
- "Share all" button: full breakdown as multi-line text, WhatsApp-friendly (primary distribution channel)

---

## Vision Extraction Contract

**API**: Gemini 2.5 Flash, `generateContent` endpoint, with `responseMimeType: application/json` and a response schema.

**Prompt** (system / instruction):
```
You are a receipt parser. Extract every line item from the receipt image.
Return ONLY valid JSON matching the provided schema.
- List only purchasable items. Do NOT include subtotal, total, tax, service charge, or tip as items — capture those in dedicated fields.
- `price` is the per-unit price. If the receipt shows "3 × Coke = 90", set quantity=3, price=30.
- Receipts may be in Arabic, English, or mixed. Keep `name` in the original language.
- If service charge is listed as a line on the receipt, set service_charge_listed=true.
- If tax/VAT is listed, set tax_listed=true.
- Currency: ISO 4217 code if determinable, else null.
```

**Response schema**:
```json
{
  "currency": "EGP",
  "items": [
    {"name": "string", "price": 0.0, "quantity": 1}
  ],
  "service_charge_listed": true,
  "service_charge_amount": 0.0,
  "tax_listed": true,
  "tax_amount": 0.0,
  "subtotal": 0.0,
  "total": 0.0
}
```

**Defaults from extraction**: if `service_charge_listed=true`, default the "service already included" checkbox to ON. Same for tax. Detected `currency` populates the bill currency.

---

## Calculation Engine

Pure Dart class `BillCalculator`, fully unit-tested. No I/O. Given a `Bill`, returns a `Map<String, PersonBreakdown>` where `PersonBreakdown` has `itemsShare`, `serviceShare`, `taxShare`, `tipShare`, `total`, and `assignedItems`.

**Algorithm**:
1. For each item, compute `lineTotal = price × quantity`.
2. For each item, distribute `lineTotal` equally across `assignedPersonIds.length`. If an item is unassigned, error (the UI should prevent this).
3. Sum each person's `itemsShare`.
4. Compute the bill subtotal = sum of all line totals.
5. If `serviceIncluded == false`, compute `serviceTotal = subtotal × serviceRate` and distribute across people in proportion to their `itemsShare`. Otherwise zero.
6. If `taxIncluded == false`, compute `taxTotal = subtotal × taxRate` similarly. Otherwise zero.
7. Compute `tipTotal = subtotal × additionalTipPercent / 100`, distribute proportionally to `itemsShare`.
8. Each person's `total = itemsShare + serviceShare + taxShare + tipShare`.
9. Apply optional rounding to nearest 0.5 / 1 / 5; track and display any residual cents.

---

## Implementation Phases

Each phase is a self-contained working state. Test, commit, then proceed.

### Phase 1 — Project Setup (~1–2 hours)
- `flutter create bill_split --org com.<your-handle>`
- Add all dependencies to `pubspec.yaml`
- Configure iOS minimum 13.0, Android minSdk 23
- Set up Riverpod root `ProviderScope`
- Configure app theme (light + dark)
- Set up `flutter_dotenv` and `.env` (gitignored) with `GEMINI_API_KEY`
- Set up Arabic + English localization scaffolding

### Phase 2 — Capture & Extraction (~3–4 hours)
- Build Capture screen with two CTAs
- Integrate `image_picker` (request camera + photo permissions; iOS Info.plist and Android manifest updates)
- Build `GeminiService` with the prompt + schema above
- Wire "Extract items" → API call → populate Bill state via Riverpod

### Phase 3 — Review Items Screen (~2–3 hours)
- Editable list UI with name/price/qty
- Add row, delete row (swipe), edit in place
- Validation rules
- Navigate forward when items list non-empty

### Phase 4 — People Screen (~1–2 hours)
- Chip input with color cycling
- Hive-backed recent names (persist on bill save)
- Navigate forward when ≥ 1 person

### Phase 5 — Assignment Screen (~4–5 hours)
- Build tap-mode first (item → modal with per-person checkboxes)
- Visual: avatar bubble cluster per item showing assignees
- Then add drag-and-drop as an enhancement (don't block release on it)
- Unassigned-items warning banner with quick-fix actions

### Phase 6 — Calculation Engine (~1–2 hours)
- Pure-Dart `BillCalculator` class
- Unit tests covering: simple split, mixed inclusion of service/tax, rounding modes, shared items, negative-price items, single-person bill

### Phase 7 — Result Screen & Sharing (~2–3 hours)
- Per-person cards with full breakdown
- Format share string in Arabic and English (locale-aware)
- Copy per-person, share-all via `share_plus`

### Phase 8 — Persistence & History (~2 hours)
- Hive type adapters for `Bill`, `BillItem`, `Person`
- Save bill on result screen
- History tab listing past bills, tap to reopen result view

### Phase 9 — Polish (~2–3 hours)
- Verify Arabic RTL across every screen
- Empty / loading / error states everywhere
- First-run onboarding bottom sheet
- App icon placeholder
- Smoke-test on real device for both platforms

---

## Edge Cases and Decisions

- **Extraction returns nothing or garbage**: error state with "Enter manually" fallback.
- **Offline**: detect and disable extraction; allow manual entry.
- **Quantity > 1**: row treated as one assignment unit; no per-unit splitting across people in MVP.
- **Negative line (discount / promo)**: allowed; user picks "apply to specific people" or "split among all" via a per-line toggle.
- **Currency**: detected by extraction, overridable in config; only one currency per bill.
- **Rounding residual**: if per-person rounding leaves a few cents/piastres unaccounted, show "remainder: X.XX EGP" without distributing it.
- **Image too large**: compress to max 1600px long edge before upload to keep API latency and cost down.

---

## Non-Goals for MVP

- No accounts, no cloud sync, no multi-device collaboration
- No payment / settlement integration (Splitwise-style)
- No weighted splits
- No multi-currency on a single bill
- No web/desktop targets (mobile only)

---

## Configuration and Secrets

- `GEMINI_API_KEY` loaded via `flutter_dotenv` from a gitignored `.env`
- Add a "demo mode" toggle that uses a hard-coded sample bill so the app works without an API key during development and review
- Document key acquisition in README (Google AI Studio link, free tier limits)

---

## Testing

- **Unit tests**: `BillCalculator` math, covering all configuration permutations
- **Widget tests**: assignment screen — assign person, verify state
- **Manual**: 5 real receipts (3 Egyptian Arabic, 2 English) shot in varying lighting; verify extraction quality and end-to-end flow

---

## Deliverables

- Flutter app building cleanly on iOS Simulator and Android Emulator
- README: setup, env config, Gemini API key instructions, build & run commands
- `/test_data` folder with sample receipt images and expected extracted JSON for offline testing
- All unit tests passing

---

## Implementation Order — Instruction to Claude Code

Work phase by phase. After each phase: run `flutter analyze`, run tests, verify the app builds and the new screens are reachable. Commit at the end of each phase with a descriptive message. Do not skip ahead — Phase 5 (assignment) and Phase 6 (calculator) are the highest-risk parts and need full attention when their phase arrives.

Start with Phase 1.
