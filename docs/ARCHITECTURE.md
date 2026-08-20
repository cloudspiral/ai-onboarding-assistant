# Architecture and data flow

## Components

- `apps/web`: Next.js 16 / React 19 TypeScript interface, Supabase anonymous session bootstrap, onboarding state, document confirmation, booking, data deletion, privacy page, and role-protected analytics UI.
- `apps/api`: Rails 8 JSON API with authentication, onboarding orchestration, OCR, booking transactions, deletion, analytics, health checks, and the single OpenAI boundary.
- `supabase`: production PostgreSQL schema, seed data, row-level security, and Auth configuration.
- `load`: k6 benchmark for the deterministic safety path.

## Request flow

1. The browser silently creates or restores an isolated anonymous Supabase Auth session, avoiding signup and password friction for the onboarding user. A creation hook rejects permanent-account signup; staff identities are provisioned separately.
2. Requests carry the Supabase access token to Rails. In local development only, an `X-Demo-User-Id` fallback is enabled by `AUTH_MODE=development`.
3. Rails verifies the JWT against the project's JWKS, then scopes all user records by the token subject. Admin access additionally requires `app_metadata.role=admin` and writes a PII-free access audit for allowed and denied attempts.
4. Chat turns pass through `ChatOrchestrator`. Urgent content is handled statically; all actual model traffic passes through `AiClient`.
5. After explicit consent, an uploaded JPEG/PNG is decoded, OCR'd locally, mapped to three fields, and immediately unlinked. Extracted fields are not persisted until the user confirms or edits them.
6. Booking locks the selected slot and relies on unique database constraints for both slot and onboarding-session uniqueness.
7. Deletion removes the user's booking, extracted details, consent events, analytics, and onboarding session, attempts to delete the Supabase Auth identity, and retains only a non-identifying deletion audit.

## Failure boundaries

- `AiClient` returns `Result::Failure`; the API returns a typed retryable error and the UI offers retry or manual continuation.
- `OcrService` returns typed validation, engine, or low-result failures; the UI opens the same editable form with blank fields.
- A database outage is reflected by the dependency health endpoint; successful mutations are transactional.
- SMTP is not configured, so booking confirmation never claims an email was sent.

## Production topology

The web and API are separate Railway services built from their own Dockerfiles. Supabase provides Auth and PostgreSQL. Browser-to-service and service-to-provider traffic use TLS; Supabase encrypts managed database storage at rest.
