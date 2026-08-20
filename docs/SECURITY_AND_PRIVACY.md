# Security and privacy

## Data minimization and consent

- Document processing is disabled until an explicit consent event is recorded.
- Only full name, date of birth, and address are extracted.
- The raw upload exists only in a request-scoped temporary file and is closed/unlinked after OCR, including error paths.
- Partial extraction is shown as editable fields; missing values remain blank and are never fabricated.
- Revocation and deletion remove extracted PII and stop document processing. The retained audit contains only the deletion event identifier and timestamp.

## Authentication and authorization

- Production uses a dedicated Supabase project and verifies access tokens against its JWKS, issuer, and audience.
- Each user query is scoped to the authenticated token subject.
- Admin analytics require `app_metadata.role=admin`; the server does not trust a browser-provided role in production.
- Supabase tables have RLS enabled and no direct anonymous/authenticated grants. Rails is the application data boundary.
- The header-based demo identity is restricted to non-production with `AUTH_MODE=development`.

## LLM and logging boundary

- `AiClient` is the only OpenAI call site.
- Requests set `store=false`; raw ID images and OCR output are never sent to the provider.
- Logs include only operation, model, duration, success/failure, retry count, timeout, and sanitized error type.
- Rails parameter filtering covers tokens, secrets, passwords, identity fields, message content, and document input. Analytics events carry allow-listed non-identifying metadata only.
- Tests assert that sensitive prompts and responses do not appear in logs and that provider failures return typed fallbacks.

## Upload controls

- Accepted formats: JPEG and PNG.
- Maximum size: 8 MiB.
- The service validates declared MIME type, file signature/decode result, and image integrity before OCR.
- Non-image, corrupt, missing, and oversized inputs produce typed 4xx responses and manual-entry fallback.

## Retention and compliance note

Raw source-image retention is zero after request processing. Confirmed fields remain until the user deletes their data or an operator applies an approved organizational retention schedule. The demo assumes a sensitive-service context but is not itself a certification or a claim of HIPAA, PCI DSS, or other regulatory compliance. A regulated production launch still requires a data-processing inventory, vendor agreements/BAAs where applicable, access review, incident response, backup/deletion validation, and counsel/security approval.

## Secret handling

Secrets are environment-only and ignored by Git. Production credentials are held in Supabase/Railway and the maintainer's macOS Keychain. `.env.example` contains names and safe defaults only.
