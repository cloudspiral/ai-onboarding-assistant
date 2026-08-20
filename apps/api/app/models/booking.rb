class Booking < ApplicationRecord
  belongs_to :onboarding_session
  belongs_to :appointment_slot
  validates :reference, presence: true, uniqueness: true

  def public_payload
    {
      reference: reference,
      starts_at: appointment_slot.starts_at.iso8601,
      channel: appointment_slot.channel,
      email_sent: false
    }
  end
end
