# bill-totals Specification

## Purpose
TBD - created by archiving change add-item-people-assignment-split. Update Purpose after archive.
## Requirements
### Requirement: Compute per-diner item subtotal
The system SHALL compute, for each diner, a pre-tax subtotal equal to the sum of `item.price / count(assigned_diners_for_item)` over every item the diner is assigned to.

#### Scenario: Item split equally between two diners
- **WHEN** item X costs 20.00 and is assigned to diners A and B
- **THEN** A's subtotal includes 10.00 and B's subtotal includes 10.00

#### Scenario: Diner assigned to multiple items
- **WHEN** diner A is the sole assignee of item X (10.00) and one of two assignees of item Y (8.00)
- **THEN** A's subtotal is 14.00

### Requirement: Allocate tax proportionally
The system SHALL allocate the detected tax amount to each diner in proportion to that diner's pre-tax subtotal relative to the sum of all diner subtotals.

#### Scenario: Tax split by share of subtotal
- **WHEN** tax is 5.00, A's subtotal is 15.00, and B's subtotal is 35.00 (total 50.00)
- **THEN** A's tax share is 1.50 and B's tax share is 3.50

#### Scenario: Tax is zero or missing
- **WHEN** the receipt's `charges.tax` is 0 or null
- **THEN** every diner's tax share is 0

### Requirement: Allocate service charge proportionally
The system SHALL allocate the detected service charge to each diner using the same proportional formula as tax.

#### Scenario: Service split by share of subtotal
- **WHEN** service is 4.00, A's subtotal is 10.00, and B's subtotal is 30.00 (total 40.00)
- **THEN** A's service share is 1.00 and B's service share is 3.00

#### Scenario: Service is zero or missing
- **WHEN** the receipt's `charges.service` is 0 or null
- **THEN** every diner's service share is 0

### Requirement: Per-diner grand total
The system SHALL compute each diner's grand total as `subtotal + tax_share + service_share`, displayed rounded to the smallest currency unit (cents).

#### Scenario: Grand total includes all components
- **WHEN** A's subtotal is 15.00, tax share is 1.50, and service share is 1.50
- **THEN** A's grand total is 18.00

### Requirement: Totals sum to the bill total
The system SHALL ensure that the sum of all per-diner grand totals equals the bill's items + tax + service total, up to a rounding residual of at most one cent per diner.

#### Scenario: Two-diner bill reconciles to total
- **WHEN** items sum to 50.00, tax is 5.00, service is 4.00 (grand total 59.00), and there are two diners
- **THEN** the sum of A's grand total and B's grand total equals 59.00 within a 0.02 tolerance

#### Scenario: Rounding residual surfaced
- **WHEN** rounding causes the sum of diner totals to differ from the bill grand total by a non-zero amount
- **THEN** the summary view displays the residual amount as a labeled rounding note

### Requirement: Refuse to finalize while items are unassigned
The system SHALL NOT mark a split as finalized while one or more items have zero assigned diners; it SHALL surface a clear indicator of which items remain unassigned.

#### Scenario: Unassigned items block finalize
- **WHEN** at least one item has zero assignees and the user attempts to finalize the split
- **THEN** the system prevents finalization and shows the count and names of the unassigned items

### Requirement: Totals update reactively on assignment edits
The system SHALL recompute and display updated per-diner totals immediately whenever a diner or assignment is added, removed, or changed.

#### Scenario: Toggling an assignment updates totals
- **WHEN** the user assigns or unassigns any diner to any item
- **THEN** the visible per-diner totals reflect the new assignment without requiring a manual refresh
