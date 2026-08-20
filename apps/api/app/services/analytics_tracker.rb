class AnalyticsTracker
  def self.record(session:, event_name:, step: nil, duration_ms: nil, properties: {})
    AnalyticsEvent.create!(
      anonymous_session_id: session.user_id,
      event_name: event_name,
      step: step,
      duration_ms: duration_ms,
      properties: properties.slice(*AnalyticsEvent::ALLOWED_PROPERTIES)
    )
  rescue ActiveRecord::ActiveRecordError
    nil
  end
end
