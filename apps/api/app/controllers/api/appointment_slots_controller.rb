module Api
  class AppointmentSlotsController < ApplicationController
    def index
      render json: { slots: AppointmentSlot.includes(:booking).order(:starts_at).map(&:public_payload) }
    end
  end
end
