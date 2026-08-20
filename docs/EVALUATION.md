# Evaluation report

The evaluation harness is `apps/api/lib/ai_evaluation.rb` and runs with `rake ai:eval`. All fixtures are synthetic and deterministic.

## Dataset composition

- OCR: 30 documents / 90 fields — 12 clean, 8 phone, 5 skewed, 3 glare, 2 hard.
- Intent: 50 utterances — 10 each for provide-details, ask-question, request-reschedule, express-distress, and out-of-scope.
- Stress/safety: 45 utterances — 20 neutral, 20 elevated, 5 urgent. Neutral examples deliberately include five upload/camera/file complaints.
- Analytics seed: 120 sessions / 434 aggregate events.
- Booking seed: 9 slots, 2 pre-booked.

## Latest live scorecard

Run on 2026-08-20 in the Ruby 3.4.7 Linux/aarch64 container with Tesseract 5.3.0 and `gpt-5.6-luna`:

| Measure | Result | Threshold |
|---|---:|---:|
| OCR field accuracy | 100% (90/90) | >=90% |
| OCR p95 latency | 194 ms | <8,000 ms |
| Intent handling | 100% (50/50) | all intents |
| Out-of-scope fallback | 100% | 100% |
| Stress macro-F1 | 1.000 | >=0.900 |
| Urgent recall | 100% | 100% |
| Upload-frustration false positives | 0 | 0 |
| Idle false positives | 0 | 0 |

The live run makes one batched structured OpenAI call for ambiguous stress cases. Deterministic safety and explicit stress policy cases never depend on the provider.

## Performance

- Service benchmark, 20 runs: OCR p95 157 ms; booking p95 4 ms.
- k6, 20 concurrent VUs for 60 seconds: 1,180 requests, 100% checks, 0 HTTP failures, 84.81 ms p95, 253.15 ms maximum.

The k6 path is the urgent static safety boundary, not a provider-capacity claim. It measures the deployed Rails/API/session/database path while avoiding a high-rate paid LLM workload. Separate live smoke calls completed in 2.11 seconds after low-latency model configuration; an earlier cold call and one batched evaluation attempt hit the 2.8-second deadline and returned the intended typed fallback, while the user-level/evaluation reruns succeeded.

Machine-readable results are committed beside this report.
