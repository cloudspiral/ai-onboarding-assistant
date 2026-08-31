class ChatOrchestrator
  ASSESSMENT_FIELDS = %w[name reason timing note].freeze
  INTENTS = %w[provide_details ask_question request_reschedule express_distress out_of_scope].freeze
  SKIPPED_ASSESSMENT_VALUE = "Complete with specialist".freeze

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

  CALM_MODE_INSTRUCTIONS = <<~PROMPT.freeze
    Calm mode is already active for this session. Regardless of the current stress
    classification, keep the reply to at most two short sentences, offer only one
    concrete next step, and make clear that the user can pause or skip. Do not say
    that stress was detected and do not diagnose the user.
  PROMPT

  ELEVATED_REPLY = "Thank you for telling me. We can take one small step, pause, or skip this for a specialist to finish with you.".freeze
  SKIP_REPLY = "That’s okay. We’ll leave this for a specialist and move to the next small step.".freeze

  def initialize(ai_client: AiClient.new)
    @ai_client = ai_client
  end

  def call(message:, field: nil, session:, skip: false)
    explicit = StressPolicy.explicit_level(message)
    if explicit == "urgent"
      session.update!(stress_mode: "elevated", calm_mode_active: true)
      return Result::Success.new(
        value: StressPolicy::CRISIS_RESPONSE.merge(calm_mode_active: true),
        metadata: { operation: "urgent_static_boundary" }
      )
    end

    if skip
      unless session.calm_mode_active? && ASSESSMENT_FIELDS.include?(field)
        return Result::Failure.new(
          code: "skip_unavailable",
          message: "This question can’t be skipped right now.",
          retryable: false,
          metadata: { operation: "assessment_skip" }
        )
      end

      session.update!(assessment: session.assessment.merge(field => SKIPPED_ASSESSMENT_VALUE))
      return Result::Success.new(
        value: {
          "intent" => "skip_question",
          "stress" => session.stress_mode,
          "level" => session.stress_mode,
          "assistant_reply" => SKIP_REPLY,
          "assessment_value" => SKIPPED_ASSESSMENT_VALUE,
          "calm_mode_active" => true
        },
        metadata: { operation: "assessment_skip" }
      )
    end

    if explicit == "elevated"
      session.update!(stress_mode: "elevated", calm_mode_active: true)
      return Result::Success.new(
        value: {
          "intent" => "express_distress",
          "stress" => "elevated",
          "level" => "elevated",
          "assistant_reply" => ELEVATED_REPLY,
          "calm_mode_active" => true
        },
        metadata: { operation: "elevated_static_adaptation" }
      )
    end

    calm_mode_active = session.calm_mode_active?

    result = @ai_client.structured(
      operation: "assessment_turn",
      instructions: calm_mode_active ? "#{INSTRUCTIONS}\n#{CALM_MODE_INSTRUCTIONS}" : INSTRUCTIONS,
      input: message,
      schema: SCHEMA
    )
    return result unless result.success?

    value = result.value
    detected_stress = explicit || value["stress"]
    value["stress"] = detected_stress
    value["intent"] = detected_stress == "elevated" ? "express_distress" : IntentPolicy.classify(message)

    updates = {}
    if detected_stress == "elevated"
      calm_mode_active = true
      value["assistant_reply"] = ELEVATED_REPLY
      updates[:stress_mode] = "elevated"
      updates[:calm_mode_active] = true
    end
    if field.present? && value["intent"] != "express_distress"
      updates[:assessment] = session.assessment.merge(field => message)
    end
    session.update!(updates) if updates.any?

    Result::Success.new(
      value: value.merge("level" => detected_stress, "calm_mode_active" => calm_mode_active),
      metadata: result.metadata
    )
  end
end
