require "rails_helper"

RSpec.describe "Onboarding deletion", type: :request do
  around do |example|
    original = ENV["AUTH_MODE"]
    ENV["AUTH_MODE"] = "development"
    example.run
    ENV["AUTH_MODE"] = original
  end

  it "removes the onboarding record and its pseudonymous analytics" do
    user_id = SecureRandom.uuid
    session = OnboardingSession.create!(user_id:)
    AnalyticsEvent.create!(anonymous_session_id: user_id, event_name: "chat_turn", step: "chat")

    delete "/api/onboarding", headers: { "X-Demo-User-Id" => user_id }

    expect(response).to have_http_status(:ok)
    expect(OnboardingSession.exists?(session.id)).to be(false)
    expect(AnalyticsEvent.where(anonymous_session_id: user_id)).to be_empty
    expect(DeletionAudit.last.subject_digest).to match(/\A[0-9a-f]{64}\z/)
  end
end
