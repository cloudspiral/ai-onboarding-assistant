class ChatOrchestrator
  INTENTS = %w[provide_details ask_question request_reschedule express_distress out_of_scope].freeze

  SCHEMA = {
    type: "object",
    properties: {
      intent: { type: "string", enum: INTENTS },
      stress: { type: "string", enum: %w[neutral elevated] },
      assistant_reply: { type: "string" }
    },
    required: %w[intent stress assistant_reply],
    additionalProperties: false
  }.freeze

  INSTRUCTIONS = <<~PROMPT.freeze
    You are Wren, Harbor's onboarding guide. Classify the user's intent and stress.
    This is administrative onboarding, not medical, legal, or crisis advice.
    Keep replies warm, precise, and limited to onboarding. Never invent a booking,
    policy, eligibility outcome, or service commitment. For elevated stress, use at
    most two short sentences, present only one next step, and explicitly allow pause
    or skip. For neutral stress, use at most three concise sentences. Technical
    frustration about upload/photo/file problems is neutral unless the person also
    explicitly describes emotional distress. Return only the schema.
  PROMPT

  def initialize(ai_client: AiClient.new)
    @ai_client = ai_client
  end

  def call(message:, field: nil, session:, calm_mode_opt_in: false)
    explicit = StressPolicy.explicit_level(message)
    return Result::Success.new(value: StressPolicy::CRISIS_RESPONSE, metadata: { operation: "urgent_static_boundary" }) if explicit == "urgent"

    result = @ai_client.structured(
      operation: "assessment_turn",
      instructions: INSTRUCTIONS,
      input: message,
      schema: SCHEMA
    )
    return result unless result.success?

    value = result.value
    value["intent"] = IntentPolicy.classify(message)
    value["stress"] = explicit if explicit
    if value["stress"] == "elevated"
      value["assistant_reply"] = "Thank you for telling me. We can take one small step, pause, or skip this for a specialist to finish with you."
      session.update!(stress_mode: "elevated", calm_mode_opt_in: true) if calm_mode_opt_in
    end
    if field.present?
      session.update!(assessment: session.assessment.merge(field => message))
    end

    Result::Success.new(value: value.merge("level" => value["stress"]), metadata: result.metadata)
  end
end
