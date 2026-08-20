require "rails_helper"

RSpec.describe "Supporting services" do
  it "treats missing Supabase admin credentials as an explicit non-production skip" do
    result = SupabaseAdminClient.new(url: nil, service_key: nil).delete_user(SecureRandom.uuid)
    expect(result).to be_success
    expect(result.metadata).to include(skipped: true)
  end

  it "records only allow-listed, non-identifying analytics properties" do
    session = OnboardingSession.create!(user_id: SecureRandom.uuid)
    expect {
      AnalyticsTracker.record(session:, event_name: "chat_turn", step: "chat", properties: { "intent" => "ask_question", "name" => "must be dropped" })
    }.to change(AnalyticsEvent, :count).by(1)
    expect(AnalyticsEvent.last.properties).to eq("intent" => "ask_question")
  end
end
