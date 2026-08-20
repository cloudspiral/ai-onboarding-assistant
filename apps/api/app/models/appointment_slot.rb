class AppointmentSlot < ApplicationRecord
  has_one :booking, dependent: :restrict_with_error
  validates :starts_at, presence: true, uniqueness: true

  def public_payload
    { id: id, starts_at: starts_at.iso8601, available: booking.nil? }
  end
end
