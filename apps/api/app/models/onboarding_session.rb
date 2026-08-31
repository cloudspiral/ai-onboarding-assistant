class OnboardingSession < ApplicationRecord
  STEPS = %w[chat details booking done].freeze

  has_one :document_detail, dependent: :destroy
  has_many :consent_events, dependent: :destroy
  has_one :booking, dependent: :destroy

  validates :user_id, presence: true, uniqueness: true
  validates :step, inclusion: { in: STEPS }
  validates :stress_mode, inclusion: { in: %w[neutral elevated] }

  def public_payload
    {
      step: step,
      status: status,
      stress_mode: stress_mode,
      calm_mode_active: calm_mode_active,
      assessment: assessment,
      details: document_detail&.public_payload,
      booking: booking&.public_payload
    }
  end
end
