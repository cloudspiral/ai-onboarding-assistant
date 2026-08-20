require "rails_helper"

RSpec.describe ChatOrchestrator do
  let(:session) { OnboardingSession.create!(user_id: SecureRandom.uuid) }

  it "bypasses the model and returns the static crisis boundary for urgent text" do
    client = instance_double(AiClient)
    expect(client).not_to receive(:structured)
    result = described_class.new(ai_client: client).call(message: "I cannot stay safe right now", session:)

    expect(result).to be_success
    expect(result.value[:level]).to eq("urgent")
    expect(result.value[:assistant_reply]).to include("911", "988")
  end

  it "returns provider failures for a retry or manual fallback instead of inventing a reply" do
    failure = Result::Failure.new(code: "timeout", message: "The assistant is temporarily unavailable.", retryable: true, metadata: {})
    client = instance_double(AiClient, structured: failure)
    result = described_class.new(ai_client: client).call(message: "My name is Sample Person", field: "name", session:)

    expect(result).to equal(failure)
    expect(session.reload.assessment).to be_empty
  end

  it "adapts an elevated reply and only persists calm pacing after opt-in" do
    success = Result::Success.new(value: { "intent" => "provide_details", "stress" => "neutral", "assistant_reply" => "generic" }, metadata: {})
    client = instance_double(AiClient, structured: success)
    result = described_class.new(ai_client: client).call(message: "I feel overwhelmed", field: "note", session:, calm_mode_opt_in: true)

    expect(result.value["level"]).to eq("elevated")
    expect(result.value["assistant_reply"]).to include("one small step", "pause", "skip")
    expect(session.reload).to have_attributes(stress_mode: "elevated", calm_mode_opt_in: true)
  end
end
