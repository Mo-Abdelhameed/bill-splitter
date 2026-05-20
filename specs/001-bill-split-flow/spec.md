# Feature Specification: Bill Split Flow

**Feature Branch**: `001-bill-split-flow`

**Created**: 2026-05-19

**Status**: Draft

**Input**: User description: "i am building a bill splitter app in flutter. the users should be able to input the names of people sharing the bill, take a photo of the bill, the app shows the items and the prices and show the taxes and service if available. the user dargs the names on the items. a name can be assigned to multiple items and items can be shared by more than one person. The app then shows the number that should be paid by each person so that the total of the invoice is paid."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Split a paper receipt among friends (Priority: P1)

A group of people who have just finished a meal want to divide the check fairly based on what each person actually ordered. One person opens the app, types in every diner's name, snaps a photo of the receipt, drags each name onto the items that person consumed (sharing dishes where appropriate), and instantly sees what each person owes — including their share of any tax or service charge on the receipt.

**Why this priority**: This single journey is the entire product promise. Without it, the app delivers no value; with it, the app does everything a bill splitter is supposed to do. Every other story refines or hardens this one core flow.

**Independent Test**: Hand the phone to a non-technical user along with a real paper receipt and a group of names. They should be able to enter the names, capture the receipt, assign items to people, and arrive at correct per-person totals without external help. The sum of per-person totals must equal the bill's total.

**Acceptance Scenarios**:

1. **Given** three friends who shared four items (each ordered one main, one shared dessert), **When** the user enters all three names, captures the receipt, and assigns each person to their respective main plus all three to the shared dessert, **Then** the app shows three per-person totals whose sum equals the bill's total.

2. **Given** a receipt with an already-included service charge of 12% and an already-included tax of 14%, **When** the user proceeds through the flow without toggling anything, **Then** the per-person totals correctly reflect those inclusive charges (i.e., the per-person totals collectively equal the bill's total, not the bill's total plus another 26%).

3. **Given** a single item shared among two people (e.g., one bottle of water split), **When** the user assigns both names to that item without setting weights, **Then** each of those two people pays exactly half of the item's price in their respective total.

4. **Given** an item shared among two people where one consumed twice as much (e.g., a pitcher), **When** the user sets the weights for that item to 2:1, **Then** the heavier-consumption assignee pays 2/3 of the item's price and the lighter pays 1/3, and both per-person totals reflect this.

---

### User Story 2 - Recover from a failed receipt scan (Priority: P2)

A user's photo is blurry, in poor lighting, or the receipt is handwritten — the automatic item extraction fails or returns garbage. The user should not be stuck; the app must offer a clear way to enter items by hand and continue the split.

**Why this priority**: Real-world receipts are messy. Without this fallback, any extraction failure becomes a dead end and the app feels unreliable. It is not the core promise (P1) but is required for the app to function dependably in normal use.

**Independent Test**: Provide an obviously unparseable image (e.g., a blurred photo, or simulate an extraction error). The user should reach a working manual-entry items list within two taps of the failure message, and the rest of the flow (assignment, totals) should behave identically to the photo-extraction path.

**Acceptance Scenarios**:

1. **Given** the receipt photo cannot be parsed, **When** the user sees the failure message, **Then** they can choose "enter items manually" and arrive at an empty editable items list.

2. **Given** the user successfully entered items manually, **When** they continue, **Then** the assignment screen and the per-person totals work identically to the photo-extraction path.

---

### User Story 3 - Handle receipts where tax or service is added on top (Priority: P3)

In some restaurants tax and service are NOT baked into item prices — they appear as separate lines added to the subtotal. The user must be able to tell the app this is the case so the calculation adds those charges on top of each person's share rather than treating them as already included.

**Why this priority**: Common in many regions but not universally present. The P1 flow can default to "inclusive" pricing and ship; this story tightens correctness for the remaining cases.

**Independent Test**: Provide a receipt where service is listed as a separate line that's added to the subtotal. The user should be able to toggle the relevant charge as "not yet included" and see each person's total scale up accordingly.

**Acceptance Scenarios**:

1. **Given** a receipt where service charge is listed as a separate line not added to item prices and the rate is 12%, **When** the user marks "service not included in items", **Then** each person's total includes their proportional share of the 12% service charge added on top.

2. **Given** the user toggles "tax not included" with a rate of 14%, **When** the calculation runs, **Then** each person's total includes their proportional share of the 14% tax added on top.

---

### Edge Cases

- A name field is left empty when the user proceeds from the names screen → empty names are not committed; the count of people advanced equals only the non-empty trimmed entries.
- Two entered names match case-insensitively after trimming → the system flags the duplicate so the user can disambiguate before moving on to assignment.
- An item is unassigned (no person dragged to it) when the user attempts to proceed to per-person totals → this state MUST NOT be reachable. The action that produces totals (Calculate / Continue from the assignment screen) is disabled while any item has zero assignees, and the screen surfaces which item(s) are unassigned so the user can fix the gap. Rationale (2026-05-19, user decision): "why would we reach the bill total if there's items we have not paid for?" — the bill total must always be fully covered, so unassigned items are not a permissible state.
- Extraction returns zero items → treat as extraction failure; offer the manual-entry fallback (User Story 2).
- The user denies camera AND photo-library permissions → both CTAs surface their respective inline error; the user reaches manual entry via the failure-recovery path once it's reachable.
- The bill total doesn't divide evenly across assignees (rounding residual at the smallest currency unit) → the residual is surfaced to the user (e.g., a small "remainder" line) and is not silently distributed.
- The user changes a person's assignment after totals are computed → totals recompute immediately to reflect the change.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The app MUST allow the user to enter one or more people sharing the bill, by name.
- **FR-002**: The app MUST allow the user to acquire a receipt image by either taking a photo with the device camera OR picking an existing image from the device photo library.
- **FR-003**: The app MUST present the receipt's purchasable line items, each with a name and a unit price, to the user for review and editing.
- **FR-004**: If the receipt lists tax and/or a service charge, the app MUST surface them to the user as editable values that can be marked as "already included in item prices" or "not included in item prices".
- **FR-005**: The app MUST allow the user to assign a person to an item via a drag-and-drop interaction, AND MUST provide a tap-based assignment fallback for accessibility and small-screen usability.
- **FR-006**: The app MUST allow many-to-many assignment: a single person can be assigned to multiple items, AND a single item can be assigned to multiple people.
- **FR-007**: When an item is assigned to multiple people, the app MUST split that item's cost equally among the assigned people BY DEFAULT (default weight = 1 per assignee).
- **FR-007a**: The app MUST allow the user to override the default equal split by assigning a positive weight to each assignee on a per-item basis. When weights are set, the assignee's share of the item equals `item_price × (assignee_weight / sum_of_weights_for_that_item)`. When all weights are equal (the default), this reduces to an equal split.
- **FR-008**: The app MUST compute a per-person total such that the sum of all per-person totals equals the bill's total (less any explicitly surfaced rounding residual at the smallest currency unit).
- **FR-009**: When tax or service charge is marked "already included in item prices", the app MUST NOT add those charges again on top of the per-item share — they are already encoded in the displayed item prices.
- **FR-010**: When tax or service charge is marked "not included in item prices", the app MUST add each person's proportional share of those charges on top of their per-item share.
- **FR-011**: The app MUST prevent advancement to per-person totals while any item has zero assignees. The action that produces totals MUST be disabled in this state, and the assignment screen MUST surface which item(s) are unassigned so the user can fix the gap.
- **FR-012**: The app MUST allow the user to edit any extracted item's name or price before finalizing the split.
- **FR-013**: The app MUST allow the user to add a new item to the list manually (to cover items the extractor missed or that the user wants to add).
- **FR-014**: The app MUST allow the user to delete any item from the list before the split is finalized.
- **FR-015**: If receipt extraction fails for any reason — network failure, unrecognizable image, no items detected, response not parseable — the app MUST present a clearly visible path to enter items manually instead.
- **FR-016**: The app MUST display, for each person, a breakdown that includes the names of the items they are paying for, their share of each, their proportional share of any applicable tax, their share of any applicable service charge, and their grand total.
- **FR-017**: The app MUST treat name comparisons for duplicate detection (during names entry) as case-insensitive after trimming surrounding whitespace.

### Key Entities

- **Bill**: The single in-progress split. Holds one receipt image, a roster of people, a list of items, an optional tax value, an optional service-charge value, and the assignment relationships between people and items.
- **Person**: A single individual sharing the bill. Identified by a name. Belongs to exactly one Bill.
- **Item**: A single purchasable unit from the receipt with a name and a unit price. Belongs to exactly one Bill. May be assigned to zero or more People.
- **Assignment**: The many-to-many relationship between Person and Item; drives the per-person cost calculation.
- **Tax / Service Charge**: Numeric values associated with the Bill, each optionally absent. Each carries a flag indicating whether it is already included in the item prices or applied on top of them.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A user with a paper receipt and a group of names can complete a bill split end-to-end (names → photo → assignment → per-person totals) in under 90 seconds in the happy path.
- **SC-002**: The sum of all per-person totals equals the bill's total (subtotal plus any applicable tax and service charges), with any unavoidable rounding residual at the smallest currency unit displayed to the user rather than silently absorbed.
- **SC-003**: When given a receipt the extractor cannot parse, the user reaches a working manual-entry items list in two taps or fewer from the failure message.
- **SC-004**: At least 90% of first-time users complete an end-to-end split without external assistance on their first attempt, measured via supervised onboarding sessions.
- **SC-005**: Toggling tax or service between "included" and "not included" updates the displayed per-person totals within 1 second of the tap.
- **SC-006**: It is impossible for the user to arrive at the per-person-totals screen while any item is unassigned (verified by inspection: the action that would advance is mechanically disabled in that state).

## Assumptions

- The app is used by a single person at a time on a single device; no multi-device collaboration or real-time co-editing is in scope for v1.
- The default locale assumes Egyptian Pound (EGP) currency, 12% service charge default, and 14% VAT default; the user can override these per bill.
- Persistence of past bills (history) is not in scope for v1.
- Sharing the per-person breakdown to external apps (e.g., WhatsApp) is desirable but not required for v1; it is treated as a future enhancement.
- Authentication, user accounts, and cloud sync are explicitly out of scope.
- The app targets iOS and Android phones. Tablets, web, and desktop are out of scope unless explicitly added later.
- Receipts may be in Arabic, English, or a mix; item names are preserved in their original language.
- A single bill has a single currency. Multi-currency receipts are not supported in v1.
- The receipt is reasonably legible to a human; severely damaged or handwritten receipts may fall back to manual entry per User Story 2.
- An "additional cash tip" beyond the receipt's service charge is not collected in v1.
