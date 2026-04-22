class Article < ApplicationRecord
  validates :title, :slug, :excerpt, :body, presence: true
  validates :slug, uniqueness: true

  scope :published, -> { where(published: true).order(published_on: :desc, created_at: :desc) }
  scope :featured, -> { published.where(featured: true) }

  before_validation :generate_slug

  private

  def generate_slug
    self.slug = title.to_s.parameterize if slug.blank?
  end
end
