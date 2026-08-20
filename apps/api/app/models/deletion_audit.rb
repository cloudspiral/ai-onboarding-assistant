class DeletionAudit < ApplicationRecord
  validates :subject_digest, presence: true
end
