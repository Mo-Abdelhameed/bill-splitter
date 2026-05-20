# Backend API v1 Contract

This file is the source of truth for the HTTP contract between the Flutter app (frontend) and the Python FastAPI service (backend). Any change to this contract requires updating BOTH sides plus the tests that exercise the contract.

## Base URLs

| Environment | URL |
|---|---|
| Production (Cloud Run, TBD on first deploy) | `https://<service>-<hash>-<region>.a.run.app/v1` |
| Local dev (uvicorn) | `http://localhost:8080/v1` |

The frontend resolves the base URL from an env var at build time: `--dart-define=BACKEND_URL=https://…/v1`.

## Authentication

Every request to a `/v1/*` endpoint MUST include a Firebase Anonymous Auth ID token:

```
Authorization: Bearer <firebase-id-token>
```

The backend verifies the token using `firebase-admin`:
- Signature check against Firebase's published public keys
- `aud` claim equals the Firebase project ID configured in `backend/.env`
- `exp` claim is in the future
- Tokens are short-lived (~1 hour); the Flutter SDK refreshes them automatically

Requests without a valid token return `401 Unauthorized` with error code `unauthorized`. The token's `uid` is logged but no per-user state is kept (backend is stateless v1).

## Endpoints

### `POST /v1/extract`

Extract items from a receipt image.

#### Request

- **Method**: `POST`
- **Path**: `/v1/extract`
- **Headers**:
  - `Authorization: Bearer <firebase-id-token>` (REQUIRED)
  - `Content-Type: multipart/form-data; boundary=...`
- **Body**: multipart/form-data with one part:
  - `image`: binary file
    - Max size: **5 MB** (enforced server-side; clients should resize to 1600 px max-long-edge before upload — see STORY-003)
    - Allowed types: `image/jpeg`, `image/png`

#### Response — success

- **Status**: `200 OK`
- **Headers**: `Content-Type: application/json`
- **Body**:
  ```json
  {
    "items": [
      { "name": "pasta", "price": 50.0 },
      { "name": "pasta", "price": 50.0 },
      { "name": "salad", "price": 30.0 }
    ],
    "tax":     14.0,
    "service": 12.0
  }
  ```
- Semantics:
  - `items[]` contains one entry per single unit of purchase. The backend instructs Gemini, via the system prompt, to expand quantity-> 1 lines into N entries.
  - `tax` is the numeric tax amount listed on the receipt, OR `null` if no tax line.
  - `service` is the numeric service-charge amount, OR `null` if absent.

#### Response — errors

All non-2xx responses share this envelope:

```json
{ "error": "<code>", "message": "<human-readable>" }
```

| HTTP | `error` code | Cause |
|---|---|---|
| `400` | `bad_image` | Missing `image` part, malformed multipart, or `Content-Type` not multipart/form-data |
| `401` | `unauthorized` | Missing `Authorization` header, malformed token, or token rejected by `firebase-admin` |
| `413` | `image_too_large` | Image > 5 MB |
| `415` | `bad_image` | Image content-type is not `image/jpeg` or `image/png` |
| `502` | `network` | Backend could not reach Gemini (DNS, TLS, connection error) |
| `502` | `http` | Gemini returned a non-2xx HTTP response |
| `504` | `network` | Gemini request exceeded 30-second timeout |
| `500` | `parse` | Gemini's response body could not be JSON-decoded |
| `500` | `schema` | Decoded JSON did not match the schema (e.g., missing `items`, wrong types) |
| `500` | `empty` | Schema valid but `items` array empty |

## Frontend behavior expectations

The frontend's `BackendExtractorImpl` MUST:
1. Attach the Firebase ID token to every request via a `dio` interceptor.
2. Map non-2xx responses to `ExtractionFailure` enum cases for AC-14 handling:
   - `401` → `ExtractionFailure.unauthorized` (a NEW case added to the existing `ExtractionFailure` enum — caller treats as "auth lost; sign in anonymously again")
   - `400 / 413 / 415` → `ExtractionFailure.parse` (image was malformed)
   - `502 / 504 network` → `ExtractionFailure.network`
   - `502 http` → `ExtractionFailure.http`
   - `500 parse` → `ExtractionFailure.parse`
   - `500 schema` → `ExtractionFailure.schema`
   - `500 empty` → `ExtractionFailure.emptyItems`
3. Treat the original `ExtractionFailure` value contract (5 cases) as extended to 6: add `unauthorized` so the UI can prompt re-auth without a full app restart. Update STORY-002's superseding plan accordingly.

## Versioning

The path prefix `/v1/` is part of the URL. Breaking changes get a new prefix (`/v2/`, etc.) and the old version keeps working for at least one deployment cycle. Non-breaking additions (new optional fields in the response) do not bump the version.

## Observability

The backend logs (stdout, captured by Cloud Run):
- Request method, path, status code, duration
- Firebase `uid` (for rate-limit tracking later; no per-user storage)
- Gemini latency and any error details (sanitized; no image bytes in logs)

No request/response bodies are logged in v1.

## Future endpoints (not in v1)

- `POST /v1/extract/retry` — if a previous call failed, retry with the same image bytes (cached server-side). Not in v1 since backend is stateless.
- `POST /v1/bills` — persist a bill for cross-device sync. Not in v1; constitution forbids accounts.
