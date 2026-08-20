class AdminAccessAudit < ApplicationRecord
  ACTIONS = %w[analytics_viewed analytics_denied].freeze

  validates :actor_digest, presence: true
  validates :action, inclusion: { in: ACTIONS }
end
