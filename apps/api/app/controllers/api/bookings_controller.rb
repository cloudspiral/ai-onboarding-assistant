module Api
  class BookingsController < ApplicationController
    def show
      booking = onboarding_session.booking
      return render json: { booking: nil } unless booking

      render json: { booking: booking.public_payload }
    end

    def create
      booking = nil
      AppointmentSlot.transaction do
        slot = AppointmentSlot.lock.find(params.require(:appointment_slot_id))
        raise SlotTaken if slot.booking.present?

        onboarding_session.booking&.destroy!
        booking = onboarding_session.create_booking!(appointment_slot: slot, reference: unique_reference)
        onboarding_session.update!(step: "booking")
      end
      AnalyticsTracker.record(session: onboarding_session, event_name: "booking_created", step: "booking", properties: { "outcome" => "success" })
      render json: { booking: booking.public_payload }, status: :created
    rescue SlotTaken, ActiveRecord::RecordNotUnique
      render json: { error: { code: "slot_taken", message: "That time was just booked. Please choose another opening." } }, status: :conflict
    end

    def destroy
      onboarding_session.booking&.destroy!
      render json: { booking: nil }
    end

    private

    class SlotTaken < StandardError; end

    def unique_reference
      loop do
        reference = "HB-#{SecureRandom.random_number(10_000).to_s.rjust(4, '0')}"
        return reference unless Booking.exists?(reference:)
      end
    end
  end
end
