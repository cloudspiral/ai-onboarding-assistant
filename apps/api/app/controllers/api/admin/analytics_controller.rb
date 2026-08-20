module Api
  module Admin
    class AnalyticsController < ApplicationController
      before_action :require_admin!

      def show
        sessions = OnboardingSession.all
        events = AnalyticsEvent.all
        render json: {
          totals: {
            sessions: sessions.count,
            completed: sessions.where(status: "completed").count,
            bookings: Booking.count
          },
          funnel: OnboardingSession::STEPS.index_with { |step| sessions.where(step: step).count },
          events: events.group(:event_name).count,
          step_duration_ms: events.where.not(duration_ms: nil).group(:step).average(:duration_ms).transform_values { |value| value.to_f.round },
          ocr: {
            attempts: events.where(event_name: "ocr_completed").count,
            successes: events.where(event_name: "ocr_completed").where("properties ->> 'outcome' = ?", "success").count,
            corrections: events.where(event_name: "ocr_field_corrected").count
          },
          contains_pii: false
        }
      end

      private

      def require_admin!
        return if Current.role == "admin"

        render json: { error: { code: "forbidden", message: "Admin access required." } }, status: :forbidden
      end
    end
  end
end
