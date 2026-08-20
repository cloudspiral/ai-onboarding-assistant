require "rails_helper"

RSpec.describe "Bookings", type: :request do
  around do |example|
    original = ENV["AUTH_MODE"]
    ENV["AUTH_MODE"] = "development"
    example.run
    ENV["AUTH_MODE"] = original
  end

  it "persists one booking and rejects a double booking transactionally" do
    slot = AppointmentSlot.create!(starts_at: 2.days.from_now)
    first_user = SecureRandom.uuid
    second_user = SecureRandom.uuid

    post "/api/booking", params: { appointment_slot_id: slot.id }, headers: { "X-Demo-User-Id" => first_user }, as: :json
    expect(response).to have_http_status(:created)
    expect(JSON.parse(response.body).dig("booking", "reference")).to start_with("HB-")

    post "/api/booking", params: { appointment_slot_id: slot.id }, headers: { "X-Demo-User-Id" => second_user }, as: :json
    expect(response).to have_http_status(:conflict)
    expect(JSON.parse(response.body).dig("error", "code")).to eq("slot_taken")
    expect(Booking.where(appointment_slot: slot).count).to eq(1)
  end
end
