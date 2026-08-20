class ConsentEvent < ApplicationRecord
  belongs_to :onboarding_session
  validates :event_type, inclusion: { in: %w[granted revoked] }
end
