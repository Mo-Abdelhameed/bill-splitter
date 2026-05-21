# receipt-charges-detection Specification

## Purpose
TBD - created by archiving change add-item-people-assignment-split. Update Purpose after archive.
## Requirements
### Requirement: Receipt extraction returns structured charges
The receipt-extraction endpoint SHALL return a `charges` object containing separate numeric fields for `tax` and `service`, in addition to the existing items list. Each field SHALL be a non-negative number or null when the corresponding charge is not present on the receipt.

#### Scenario: Receipt with both tax and service
- **WHEN** the receipt image contains a clearly labeled tax line and service-charge line
- **THEN** the response includes `charges.tax` and `charges.service` populated with their numeric values

#### Scenario: Receipt with no service charge
- **WHEN** the receipt has a tax line but no service-charge line
- **THEN** `charges.tax` is the tax value and `charges.service` is null (or 0)

#### Scenario: Receipt with neither tax nor service
- **WHEN** the receipt contains only item lines and a single total
- **THEN** both `charges.tax` and `charges.service` are null (or 0)

### Requirement: Charge lines are excluded from items
The extraction SHALL NOT include any line classified as tax or service in the `items` array of the response.

#### Scenario: Tax line not duplicated as an item
- **WHEN** a receipt line is identified as tax
- **THEN** that line does not appear in the returned `items` list

#### Scenario: Service line not duplicated as an item
- **WHEN** a receipt line is identified as a service charge or gratuity
- **THEN** that line does not appear in the returned `items` list

### Requirement: Detection is language- and label-tolerant
The extraction SHALL identify tax and service lines across common labels and localizations, including but not limited to: "Tax", "Sales Tax", "VAT", "TVA", "GST", "Service", "Service Charge", "Gratuity".

#### Scenario: Non-English tax label
- **WHEN** the receipt labels tax as "TVA" or "VAT"
- **THEN** the line is classified as tax and surfaced in `charges.tax`

#### Scenario: Service labelled as gratuity
- **WHEN** the receipt labels service as "Gratuity" or "Service Charge"
- **THEN** the line is classified as service and surfaced in `charges.service`

### Requirement: Detected charges are user-correctable
The client SHALL allow the user to override the detected tax and service values before finalizing the split, so that mis-classification does not block the workflow.

#### Scenario: User corrects a missing tax value
- **WHEN** the extracted `charges.tax` is null but the user knows tax is on the bill
- **THEN** the user can enter a tax amount in the summary screen and per-diner totals recompute accordingly

#### Scenario: User clears a falsely detected service charge
- **WHEN** a non-service line was mis-classified and surfaced as `charges.service`
- **THEN** the user can clear or edit the service value and totals recompute accordingly
