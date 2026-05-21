## ADDED Requirements

### Requirement: Manage diners on a bill
The system SHALL let the user add, rename, and remove diners on the current bill. Each diner SHALL have a unique identifier and a display name.

#### Scenario: Add a diner
- **WHEN** the user enters a non-empty name on the diners screen and confirms
- **THEN** the system creates a diner with a unique id and that name and includes them in the diners list

#### Scenario: Remove a diner who has item assignments
- **WHEN** the user removes a diner that is currently assigned to one or more items
- **THEN** the system removes that diner from every item's assignment set and updates totals immediately

#### Scenario: Reject duplicate empty names
- **WHEN** the user submits an empty or whitespace-only name
- **THEN** the system rejects the entry and does not create a diner

### Requirement: Assign diners to items (many-to-many)
The system SHALL support an assignment relation where one item can be assigned to multiple diners and one diner can be assigned to multiple items.

#### Scenario: Assign multiple diners to one item
- **WHEN** the user selects diners A and B for item X
- **THEN** the assignment set for item X contains both A and B

#### Scenario: Assign one diner to multiple items
- **WHEN** the user selects diner A for items X and Y
- **THEN** diner A appears in the assignment sets of both X and Y

#### Scenario: Toggle a diner off an item
- **WHEN** a diner is already assigned to an item and the user deselects them
- **THEN** the diner is removed from that item's assignment set, but their other assignments remain

#### Scenario: Item with no assigned diners
- **WHEN** an item has zero diners assigned
- **THEN** the system marks that item as unassigned and surfaces it in any unassigned-items indicator

### Requirement: Tax and service lines are not assignable
The system SHALL exclude lines identified as tax or service charges from the set of items shown on the assignment screen.

#### Scenario: Receipt has detected tax and service
- **WHEN** the assignment screen renders a receipt whose `charges.tax` and `charges.service` are non-null
- **THEN** those charges do not appear as assignable items in the list

### Requirement: Assignment state survives within a session
The system SHALL preserve the current set of diners and their item assignments across navigation between the assignment screen and the summary screen during a single bill-splitting session.

#### Scenario: Navigate to summary and back
- **WHEN** the user navigates from the assignment screen to the summary screen and then back to the assignment screen
- **THEN** all previously made assignments and diners are still present
