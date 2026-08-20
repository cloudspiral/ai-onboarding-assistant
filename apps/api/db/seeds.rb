zone = Time.find_zone!("America/Chicago")
anchor = zone.tomorrow.beginning_of_day
slot_offsets = [
  [ 0, 9, 0 ], [ 0, 11, 30 ], [ 0, 14, 0 ],
  [ 1, 10, 0 ], [ 1, 13, 30 ], [ 1, 16, 15 ],
  [ 4, 9, 30 ], [ 4, 12, 0 ], [ 4, 15, 0 ]
]
slot_times = slot_offsets.map { |days, hours, minutes| anchor + days.days + hours.hours + minutes.minutes }
slots = slot_times.map { |value| AppointmentSlot.find_or_create_by!(starts_at: value) }

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
