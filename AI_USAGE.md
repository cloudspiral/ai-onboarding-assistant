# AI Usage Disclosure

## Development tools

- **Claude Design** supplied the initial visual design ZIP used as the UI reference. Its files were treated as design input, not as project requirements.
- **OpenAI Codex** was used to inspect the design and requirements, implement the application, write tests and synthetic fixtures, run evaluations, and prepare deployment documentation.

Generated code was reviewed through the committed test, lint, security, evaluation, performance, and browser checks. No real identity data was used to generate or test the application.

## Runtime AI and OCR

- **LLM:** OpenAI Responses API with `gpt-5.6-luna`, structured JSON Schema output, `reasoning.effort=none`, low text verbosity, maximum 180 output tokens, `store=false`, a 2.8-second total deadline, and at most one retry.
- **OCR:** local Tesseract 5.3.0, invoked by the Rails `OcrService`. Raw ID images are never sent to OpenAI.
- **Intent routing:** deterministic, narrow policies cover the five evaluated intents. The model supplies a conversational reply and structured classification, while the deterministic policy remains the final router for evaluated behavior.
- **Stress adaptation:** explicit urgent/elevated/upload-frustration rules take precedence. Ambiguous turns may use the model's structured `neutral`/`elevated` classification. Urgent text never goes to the model.

All LLM calls go through `AiClient`; no component calls OpenAI directly. `AiClient` emits PII-free structured metadata and typed results. It never logs input, output, prompt, transcript, OCR text, document contents, name, date of birth, or address.

## Material prompt and configuration choices

The Wren system instruction constrains the assistant to administrative onboarding, prohibits invented bookings, policy, eligibility, or service commitments, and caps replies at two short sentences with one next step during elevated stress. Technical upload frustration is explicitly neutral unless the user also describes emotional distress. The health probe sends only a fixed synthetic message.

The live evaluation sends 21 synthetic, non-identifying stress examples in a single structured call. The committed offline mode evaluates the same set deterministically and needs no provider key.

## Data boundary

OpenAI receives only the current typed onboarding message and the administrative instruction/schema. It does not receive raw documents. Because a user could type personal information into chat, production use in a regulated setting requires the organization's contractual, retention, legal, and security review. This assessment implementation is not a claim of HIPAA compliance.
