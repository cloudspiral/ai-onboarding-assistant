class AnalyticsEvent < ApplicationRecord
  ALLOWED_PROPERTIES = %w[outcome field corrected trigger intent].freeze
  validates :event_name, :anonymous_session_id, presence: true
  validate :properties_are_non_identifying

  private

  def properties_are_non_identifying
    return if properties.keys.all? { |key| ALLOWED_PROPERTIES.include?(key.to_s) }

    errors.add(:properties, "contains a disallowed key")
  end
end
