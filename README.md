# Harbor AI Onboarding Assistant

Harbor is a privacy-conscious onboarding flow for sensitive services. A Next.js client guides the user through a structured assessment, local OCR pre-fills identity fields for confirmation, and a Rails API books an appointment in PostgreSQL. Support appears at defined friction points, while urgent language is handled by a fixed safety boundary rather than a generated response.

## Live demo

- Application: [https://web-production-42c85.up.railway.app](https://web-production-42c85.up.railway.app)
- API health: [https://api-production-21140.up.railway.app/api/health](https://api-production-21140.up.railway.app/api/health)
- Supabase project: `wnjfusxtrxyrjfvhjnxh` (dedicated to this application)

The public flow silently creates an isolated anonymous Supabase session: there is no signup form, password, or account decision between an anxious user and the first helpful question. The admin dashboard is at `/admin`; staff accounts are pre-provisioned, new permanent-account signups are rejected by an Auth hook, access requires a protected role claim, and each attempt receives a PII-free audit record. Reviewer credentials are distributed separately and are not committed. Local development uses a clearly scoped demo identity and does not require a password.

## Architecture

```text
Next.js / React 19
  | anonymous Supabase JWT
  v
Rails 8 API ---- AiClient ---- OpenAI Responses API (structured JSON, store=false)
  |      |
  |      +---- local Tesseract 5.3 OCR (raw image deleted after extraction)
  v
Supabase Postgres + Auth
```

All model traffic goes through `apps/api/app/services/ai_client.rb`. It returns typed success/failure values, applies a 2.8-second total deadline with at most one retry, and emits only PII-free metadata: operation, model, duration, success, retry count, timeout, and sanitized error type. Prompts, responses, transcripts, OCR text, identity fields, and document contents are never logged. A future Langfuse integration belongs inside this service; no tracing vendor is integrated now.

## Grader quick-start

Prerequisites: Docker Desktop and Docker Compose. Node.js 22 is only needed for running the frontend checks directly on the host.

```bash
cp .env.example .env
# Add OPENAI_API_KEY to .env for live model calls.
docker compose up --build -d
docker compose exec api bundle exec rails db:seed
```

Open [http://localhost:3000](http://localhost:3000). The Rails API is at [http://localhost:3001](http://localhost:3001), and its dependency health report is at [http://localhost:3001/api/health](http://localhost:3001/api/health).

For the document step, use `apps/web/public/sample-id.png` or any of the 30 synthetic documents under `apps/api/spec/fixtures/ocr/images/`. Never use a real identity document in development.

To stop the app without deleting its database volume:

```bash
docker compose down
```

## Tests and evaluations

```bash
# Frontend lint, types, unit/accessibility tests, and production build
npm ci
npm run lint
npm run typecheck
npm test -- --run
npm run build

# Backend tests (includes the >=80% core-logic coverage gate)
docker compose exec api bundle exec rspec
docker compose exec api bundle exec rubocop
docker compose exec api bundle exec brakeman --no-pager --exit-on-warn
docker compose exec api bundle exec bundler-audit check --update

# Deterministic/offline golden-set evaluation
docker compose exec api bundle exec rake ai:eval

# Same evaluation with one batched live OpenAI stress-classification call
docker compose exec -e EVAL_LIVE=1 api bundle exec rake ai:eval

# 20-run OCR and transactional-booking benchmarks
docker compose exec api bundle exec rake performance:benchmarks

# Required 20-VU / 60-second load test; exercises the static urgent safety path
docker run --rm -i --add-host=host.docker.internal:host-gateway \
  -v "$PWD/load:/scripts" grafana/k6 run /scripts/k6.js
```

The committed latest scorecards are in `docs/evaluation-results.json`, `docs/performance-service-results.json`, and `docs/performance-k6.json`. The k6 test deliberately targets the deterministic urgent path so it can apply the required concurrency without generating paid provider traffic; live provider latency was verified separately in the end-to-end smoke flow.

## Synthetic datasets and latest results

| Dataset | Count |
|---|---:|
| OCR documents | 30 (90 labeled fields) |
| Intent utterances | 50 (10 for each of 5 intents) |
| Stress/safety utterances | 45 |
| Analytics sessions / events | 120 / 434 |
| Appointment slots | 9 (2 pre-booked) |

Latest live evaluation on Linux/aarch64 with Tesseract 5.3.0 and `gpt-5.6-luna`:

- OCR: 90/90 fields correct, 100% overall, 194 ms p95.
- Intent routing: 50/50 handled, 100% out-of-scope fallback.
- Stress/safety: macro-F1 1.000, urgent recall 100%, zero upload-frustration or idle false positives.
- Service benchmarks: OCR 157 ms p95; booking 4 ms p95.
- k6: 1,180 requests, 20 VUs for 60 seconds, 0 HTTP failures, 84.81 ms p95.
- Backend: 21 RSpec examples, 0 failures, 80.32% core line coverage.

The fixture generator is deterministic:

```bash
docker compose exec api bundle exec ruby script/generate_synthetic_fixtures.rb
```

## Tone and pacing policy

Harbor does not diagnose emotion. It uses a narrow, testable policy:

- Explicit imminent-danger phrases bypass the model and return a fixed U.S. 911/988 boundary.
- Explicit stress phrases produce one small next step and offer pause/skip.
- Upload, photo, camera, file, image, or document frustration is neutral unless emotional distress is also explicit.
- A 10-second pause, upload failure, or uncertainty can show one contextual support card; the same card is not repeated in a session.
- A slower persistent pace is enabled only after the user checks the calm-pacing opt-in. Otherwise adaptation applies only to the current response.

The policy and trigger fixtures live in `StressPolicy`, `ChatOrchestrator`, and `spec/fixtures/stress.json`.

## Privacy and operations

See [docs/SECURITY_AND_PRIVACY.md](docs/SECURITY_AND_PRIVACY.md), [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md), and [AI_USAGE.md](AI_USAGE.md). Required configuration is documented in `.env.example`. Never commit `.env`, database passwords, Supabase service keys, OpenAI keys, reviewer passwords, or real PII.

Email delivery is intentionally not configured; the booking UI accurately reports that the appointment is saved but no email was sent.
