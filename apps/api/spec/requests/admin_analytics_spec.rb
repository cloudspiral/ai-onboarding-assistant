require "rails_helper"

RSpec.describe "Admin analytics", type: :request do
  around do |example|
    original = ENV["AUTH_MODE"]
    ENV["AUTH_MODE"] = "development"
    example.run
    ENV["AUTH_MODE"] = original
  end

  it "allows an admin and writes a PII-free access audit" do
    user_id = SecureRandom.uuid

    get "/api/admin/analytics", headers: { "X-Demo-User-Id" => user_id, "X-Demo-Role" => "admin" }

    expect(response).to have_http_status(:ok)
    expect(JSON.parse(response.body).fetch("contains_pii")).to be(false)
    audit = AdminAccessAudit.last
    expect(audit.action).to eq("analytics_viewed")
    expect(audit.actor_digest).to match(/\A[0-9a-f]{64}\z/)
    expect(audit.actor_digest).not_to include(user_id)
  end

  it "rejects a non-admin and audits the denied attempt without storing identity" do
    user_id = SecureRandom.uuid

    get "/api/admin/analytics", headers: { "X-Demo-User-Id" => user_id, "X-Demo-Role" => "user" }

    expect(response).to have_http_status(:forbidden)
    audit = AdminAccessAudit.last
    expect(audit.action).to eq("analytics_denied")
    expect(audit.actor_digest).to match(/\A[0-9a-f]{64}\z/)
    expect(audit.actor_digest).not_to include(user_id)
  end
end
