class Promotion < ApplicationRecord
  enum :discount_kind, { percentage: 0, fixed_amount: 1 }, default: :percentage

  validates :title, :slug, :discount_kind, :discount_value, presence: true
  validates :slug, uniqueness: true
  validates :promo_code, uniqueness: true, allow_blank: true
  validates :discount_value, numericality: { greater_than: 0 }

  scope :current, -> {
    today = Date.current
    where(active: true).where("starts_on <= ? AND ends_on >= ?", today, today)
  }
  scope :featured, -> { current.where(featured: true).order(:ends_on) }

  before_validation :generate_slug
  before_validation :normalize_code

  def active_now?
    active && starts_on <= Date.current && ends_on >= Date.current
  end

  def discount_for(amount)
    return 0.to_d unless active_now?

    raw_discount = percentage? ? amount * discount_value / 100 : discount_value
    [ raw_discount, amount ].min
  end

  private

  def generate_slug
    self.slug = title.to_s.parameterize if slug.blank?
  end

  def normalize_code
    self.promo_code = promo_code.to_s.upcase.presence
  end
end
