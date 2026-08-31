require "rails_helper"

RSpec.describe ChatOrchestrator do
  let(:session) { OnboardingSession.create!(user_id: SecureRandom.uuid) }

  it "bypasses the model and returns the static crisis boundary for urgent text" do
    session.update!(stress_mode: "elevated", calm_mode_active: true)
    client = instance_double(AiClient)
    expect(client).not_to receive(:structured)
    result = described_class.new(ai_client: client).call(message: "I cannot stay safe right now", field: "note", session:, skip: true)

    expect(result).to be_success
    expect(result.value[:level]).to eq("urgent")
    expect(result.value[:assistant_reply]).to include("911", "988")
    expect(session.reload.assessment).to be_empty
  end

  it "returns provider failures for a retry or manual fallback instead of inventing a reply" do
    failure = Result::Failure.new(code: "timeout", message: "The assistant is temporarily unavailable.", retryable: true, metadata: {})
    client = instance_double(AiClient, structured: failure)
    result = described_class.new(ai_client: client).call(message: "My name is Sample Person", field: "name", session:)

    expect(result).to equal(failure)
    expect(session.reload.assessment).to be_empty
  end

  it "automatically activates calm mode without storing distress as an assessment answer" do
    client = instance_double(AiClient)
    expect(client).not_to receive(:structured)
    result = described_class.new(ai_client: client).call(message: "I feel overwhelmed", field: "note", session:)

    expect(result.value["level"]).to eq("elevated")
    expect(result.value["intent"]).to eq("express_distress")
    expect(result.value["calm_mode_active"]).to be(true)
    expect(result.value["assistant_reply"]).to include("one small step", "pause", "skip")
    expect(session.reload).to have_attributes(stress_mode: "elevated", calm_mode_active: true, assessment: {})
  end

  it "uses the model classification to activate calm mode for ambiguous stress" do
    success = Result::Success.new(value: { "intent" => "provide_details", "stress" => "elevated", "assistant_reply" => "generic" }, metadata: {})
    client = instance_double(AiClient, structured: success)

    result = described_class.new(ai_client: client).call(message: "I need a moment", field: "reason", session:)

    expect(result.value).to include("level" => "elevated", "intent" => "express_distress", "calm_mode_active" => true)
    expect(session.reload).to have_attributes(stress_mode: "elevated", calm_mode_active: true, assessment: {})
  end

  it "keeps later neutral turns concise once calm mode is active" do
    session.update!(stress_mode: "elevated", calm_mode_active: true)
    success = Result::Success.new(value: { "intent" => "provide_details", "stress" => "neutral", "assistant_reply" => "Thank you. What timing works for you?" }, metadata: {})
    client = instance_double(AiClient)
    expect(client).to receive(:structured).with(hash_including(instructions: include("Calm mode is already active"))).and_return(success)

    result = described_class.new(ai_client: client).call(message: "Within a few weeks", field: "timing", session:)

    expect(result.value).to include("level" => "neutral", "calm_mode_active" => true)
    expect(session.reload.assessment).to include("timing" => "Within a few weeks")
  end

  it "skips one question without calling the model and persists a reload-safe marker" do
    session.update!(stress_mode: "elevated", calm_mode_active: true)
    client = instance_double(AiClient)
    expect(client).not_to receive(:structured)

    result = described_class.new(ai_client: client).call(message: "I’d like to skip this question.", field: "reason", session:, skip: true)

    expect(result).to be_success
    expect(result.value).to include(
      "intent" => "skip_question",
      "assessment_value" => "Complete with specialist",
      "calm_mode_active" => true
    )
    expect(session.reload.assessment).to include("reason" => "Complete with specialist")
  end

  it "rejects skip requests outside calm mode" do
    client = instance_double(AiClient)
    expect(client).not_to receive(:structured)

    result = described_class.new(ai_client: client).call(message: "I’d like to skip this question.", field: "reason", session:, skip: true)

    expect(result).not_to be_success
    expect(result.code).to eq("skip_unavailable")
    expect(session.reload.assessment).to be_empty
  end
end
