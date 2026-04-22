class Category < ApplicationRecord
  has_many :products, dependent: :restrict_with_error

  validates :name, :slug, presence: true
  validates :slug, uniqueness: true

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }

  before_validation :generate_slug

  private

  def generate_slug
    self.slug = name.to_s.parameterize if slug.blank?
  end
end
