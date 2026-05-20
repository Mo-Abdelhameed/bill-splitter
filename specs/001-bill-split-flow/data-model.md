# Phase 1 Data Model: Bill Split Flow

This document defines every entity (and wire type) the feature uses, with validation rules tracing back to the spec's Functional Requirements (FRs) and Edge Cases. It is the contract that frontend, backend, and tests all reference.

## Frontend entities (in-memory only — no persistence in v1)

### `BillState`

The root in-memory holder, passed down the widget tree via constructor injection.

| Field | Type | Notes |
|---|---|---|
| `imageBytes` | `Uint8List?` | Set by the Capture screen; consumed by the Extraction screen. Null between sessions. |
| `people` | `List<Person>` | Order matters; committed by the People screen. |
| `items` | `List<Item>` | Committed by the Extraction screen. |
| `tax` | `double?` | Null if absent from receipt OR if "Tax included" checkbox is off. |
| `service` | `double?` | Same null semantics as `tax`. |
| `assignments` | `Map<itemId, Map<personId, weight>>` | Built up by the Assignment screen. Weight defaults to 1 per assignee. |

### `Person`

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | UUID generated on entry. Stable for the lifetime of this bill. |
| `name` | `String` | Trimmed. Empty names rejected at commit time (FR-001). Duplicates rejected (FR-017, case-insensitive after trim). |

### `Item`

| Field | Type | Notes |
|---|---|---|
| `id` | `String` | UUID. |
| `name` | `String` | Preserved in original language (FR-003). |
| `price` | `double` | Per-unit price. Quantity > 1 receipts are pre-expanded into N separate items by Gemini (see wire types below). |

### Validation rules (all derived from `spec.md`)

| Rule | Source AC / FR |
|---|---|
| `people.length >= 2` to advance from People screen | FR-001 + AC-4 from STORY-001 amendment |
| Name duplicates case-insensitive, trimmed | FR-017 |
| `items.length >= 1` to advance from Extraction screen | FR-013 + AC-15 from spec |
| Every item has `assignments[itemId].length >= 1` to advance from Assignment screen | FR-011 (mechanically impossible to reach totals with unassigned items, per /speckit-clarify) |
| Tax/service `null` ⇔ "included" checkbox is off | FR-004, FR-008, FR-009 |
| Per-item weight is a positive number | FR-007a |

### State transitions (per screen)

| Screen | States | Trigger |
|---|---|---|
| People | `entering → committed` | Continue (≥2 names, no duplicates, no duplicate-warnings — see STORY-001 amendment) |
| Capture | `pre → preview → committed` | Image acquired → preview → Use this photo |
| Extraction | `pre → loading → editable → committed` OR `pre → loading → error → editable (manual fallback)` → committed | Extract items button → response (or failure path) → Continue |
| Assignment | `editing → committed` | Every item has ≥1 assignee → Continue enabled |
| Totals | `viewing` | Terminal state; no Continue. |

## Backend wire types (Pydantic models)

### `ExtractionRequest`

Sent by the Flutter app as a multipart form. The Pydantic model represents the parsed parts.

| Field | Type | Notes |
|---|---|---|
| `image` | `UploadFile` | Max 5 MB; `image/jpeg` or `image/png` only. Enforced in `app/routes/extract.py`. |

### `ExtractionResponse`

Returned by the backend on success.

```python
class ExtractedItem(BaseModel):
    name: str = Field(..., min_length=1)
    price: float = Field(..., ge=0)

class ExtractionResponse(BaseModel):
    items: list[ExtractedItem]
    tax: float | None = None
    service: float | None = None
```

Semantics (also documented in `contracts/backend-api-v1.md`):
- `items` length ≥ 1 (an empty list is treated as a failure with `error: empty` per AC-14).
- Quantity expansion: backend instructs Gemini to emit one item per single unit of purchase.
- `tax` and `service` are numbers when listed on the receipt, `null` otherwise.

### `ErrorResponse`

```python
class ErrorResponse(BaseModel):
    error: Literal[
        "bad_image",
        "unauthorized",
        "image_too_large",
        "network",
        "http",
        "parse",
        "schema",
        "empty",
    ]
    message: str
```

The `error` field maps to the frontend's `ExtractionFailure` enum so the UI can react appropriately (retry / manual fallback / re-auth).

## Cross-tier mappings (frontend ↔ backend)

| Frontend type | Backend type | Notes |
|---|---|---|
| `BillItem` (Dart) | `ExtractedItem` (Pydantic) | Both have `name: String` + `price: double`. Backend never sees the `id` (frontend generates it after extraction). |
| `ExtractionResult` (Dart, response from `BackendExtractorImpl`) | `ExtractionResponse` (Pydantic) | Field-for-field map. |
| `ExtractionFailure` (Dart enum) | `error` string in `ErrorResponse` | See `contracts/backend-api-v1.md` § "Frontend behavior expectations" for the full mapping. New case `unauthorized` is added on the frontend to handle `401` responses. |

## Non-entities (explicitly NOT modeled in v1)

- **User / Account**: not modeled; the Firebase anonymous UID is logged at the backend but never stored.
- **Past bills**: spec Assumption — history out of scope for v1.
- **Currency**: implicit (EGP); single-currency per bill; no `Currency` entity needed.
- **Subtotals**: not in the wire schema. Computed on the frontend from items + tax + service when displaying the totals screen.
- **Receipt metadata** (date, restaurant name, etc.): not extracted; out of scope.
