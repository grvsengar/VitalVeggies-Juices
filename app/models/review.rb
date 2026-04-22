class Review < ApplicationRecord
  belongs_to :product

  validates :customer_name, :title, :body, :rating, presence: true
  validates :rating, inclusion: { in: 1..5 }

  scope :approved, -> { where(approved: true).order(created_at: :desc) }
end
