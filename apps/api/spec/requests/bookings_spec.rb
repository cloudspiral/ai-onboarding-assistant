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

  it "shows only the next nine future slots and rejects a past booking" do
    past = AppointmentSlot.create!(starts_at: 1.hour.ago)
    future = 10.times.map { |index| AppointmentSlot.create!(starts_at: (index + 1).hours.from_now) }
    user_id = SecureRandom.uuid

    get "/api/appointment_slots", headers: { "X-Demo-User-Id" => user_id }

    expect(response).to have_http_status(:ok)
    payload = JSON.parse(response.body).fetch("slots")
    expect(payload.length).to eq(9)
    expect(payload.pluck("id")).not_to include(past.id)
    expect(payload.pluck("id")).to eq(future.first(9).map(&:id))

    post "/api/booking", params: { appointment_slot_id: past.id }, headers: { "X-Demo-User-Id" => user_id }, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(JSON.parse(response.body).dig("error", "code")).to eq("slot_unavailable")
  end
end
