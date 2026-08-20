slot_times = [
  "2026-08-20 09:00", "2026-08-20 11:30", "2026-08-20 14:00",
  "2026-08-21 10:00", "2026-08-21 13:30", "2026-08-21 16:15",
  "2026-08-24 09:30", "2026-08-24 12:00", "2026-08-24 15:00"
]
slots = slot_times.map { |value| AppointmentSlot.find_or_create_by!(starts_at: Time.find_zone!("America/Chicago").parse(value)) }

120.times do |index|
  user_id = format("00000000-0000-4000-8000-%012d", index + 1)
  step = index < 18 ? "chat" : index < 40 ? "details" : index < 68 ? "booking" : "done"
  session = OnboardingSession.find_or_create_by!(user_id:) do |record|
    record.step = step
    record.status = step == "done" ? "completed" : "in_progress"
  end
  next if AnalyticsEvent.exists?(anonymous_session_id: user_id, event_name: "session_started")

  AnalyticsEvent.create!(anonymous_session_id: user_id, event_name: "session_started", step: "chat", duration_ms: 0)
  AnalyticsEvent.create!(anonymous_session_id: user_id, event_name: "step_completed", step: "chat", duration_ms: 45_000 + (index * 511)) if index >= 18
  AnalyticsEvent.create!(anonymous_session_id: user_id, event_name: "step_completed", step: "details", duration_ms: 58_000 + (index * 719)) if index >= 40
  AnalyticsEvent.create!(anonymous_session_id: user_id, event_name: "ocr_completed", step: "details", duration_ms: 900 + (index * 23), properties: { "outcome" => index % 9 == 0 ? "failed" : "success" }) if index.between?(20, 99)
  AnalyticsEvent.create!(anonymous_session_id: user_id, event_name: "onboarding_completed", step: "done", duration_ms: 31_000 + (index * 347)) if index >= 68
  session
end

[
  [ 0, "00000000-0000-4000-8000-000000000069", "HB-4271" ],
  [ 4, "00000000-0000-4000-8000-000000000070", "HB-6184" ]
].each do |slot_index, user_id, reference|
  session = OnboardingSession.find_by!(user_id:)
  Booking.find_or_create_by!(appointment_slot: slots.fetch(slot_index)) do |booking|
    booking.onboarding_session = session
    booking.reference = reference
  end
end

puts "Seeded 120 synthetic analytics sessions, 9 appointment slots, and 2 taken slots."
