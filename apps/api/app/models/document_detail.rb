class DocumentDetail < ApplicationRecord
  belongs_to :onboarding_session
  validates :full_name, :date_of_birth, :address, presence: true, if: :confirmed_at?

  def public_payload
    {
      full_name: full_name,
      date_of_birth: date_of_birth&.iso8601,
      address: address,
      field_sources: field_sources,
      confirmed: confirmed_at.present?
    }
  end
end
