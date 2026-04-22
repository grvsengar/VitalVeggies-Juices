class Testimonial < ApplicationRecord
  validates :customer_name, :quote, :rating, presence: true
  validates :rating, inclusion: { in: 1..5 }

  scope :featured, -> { where(featured: true).order(rating: :desc, created_at: :desc) }
end
