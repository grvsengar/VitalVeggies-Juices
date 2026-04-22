class Faq < ApplicationRecord
  validates :question, :answer, presence: true

  scope :ordered, -> { order(:position, :created_at) }
end
