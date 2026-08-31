require "rails_helper"

RSpec.describe "Onboarding chat" do
  it "activates calm mode and persists a deliberate skipped-question marker" do
    user_id = SecureRandom.uuid
    headers = { "X-Demo-User-Id" => user_id }

    post "/api/onboarding/chat",
      params: { message: "I feel overwhelmed", field: "reason" },
      headers:,
      as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("turn")).to include(
      "intent" => "express_distress",
      "calm_mode_active" => true
    )

    post "/api/onboarding/chat",
      params: { message: "I’d like to skip this question.", field: "reason", skip: true },
      headers:,
      as: :json

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("turn")).to include(
      "intent" => "skip_question",
      "assessment_value" => "Complete with specialist",
      "calm_mode_active" => true
    )
    expect(OnboardingSession.find_by!(user_id:).assessment).to include("reason" => "Complete with specialist")
  end
end
