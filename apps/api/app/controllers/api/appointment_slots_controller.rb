module Api
  class AppointmentSlotsController < ApplicationController
    def index
      slots = AppointmentSlot.where("starts_at > ?", Time.current)
        .includes(:booking)
        .order(:starts_at)
        .limit(9)
      render json: { slots: slots.map(&:public_payload) }
    end
  end
end
