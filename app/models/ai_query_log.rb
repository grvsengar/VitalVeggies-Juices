class AiQueryLog < ApplicationRecord
  belongs_to :user, optional: true

  enum :status, {
    pending: "pending",
    succeeded: "succeeded",
    failed: "failed",
    rejected: "rejected"
  }, default: :pending

  validates :question, :status, presence: true
end
