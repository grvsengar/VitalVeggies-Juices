class Product < ApplicationRecord
  belongs_to :category
  has_many :reviews, dependent: :destroy
  has_many :order_items, dependent: :restrict_with_error

  mount_uploader :image, ProductImageUploader

  include PgSearch::Model

  enum :product_kind, { juice: 0, fruit: 1, vegetable: 2, combo: 3 }, default: :juice

  pg_search_scope :search_by_name_and_description,
                  against: %i[name description ingredients sku],
                  using: {
                    tsearch: { prefix: true }
                  }

  validates :name, :slug, :sku, :price, presence: true
  validates :slug, :sku, uniqueness: true
  validates :price, numericality: { greater_than_or_equal_to: 0 }
  validates :stock_quantity, numericality: { greater_than_or_equal_to: 0 }

  scope :active, -> { where(active: true) }
  scope :featured, -> { active.where(featured: true) }
  scope :ordered, -> { order(featured: :desc, created_at: :desc) }

  before_validation :generate_slug
  before_validation :generate_sku

  def self.filtered(params)
    scope = includes(:category).active.ordered
    scope = scope.where(category_id: params[:category]) if params[:category].present?
    scope = scope.where(product_kind: params[:kind]) if params[:kind].present?
    scope = scope.where(organic: true) if params[:organic].present?
    scope = scope.where("stock_quantity > 0") if params[:availability] == "in_stock"
    scope = scope.search_by_name_and_description(params[:q]) if params[:q].present?
    scope = apply_sort(scope, params[:sort])
    scope
  end

  def self.apply_sort(scope, sort)
    case sort
    when "price_low"
      scope.reorder(price: :asc)
    when "price_high"
      scope.reorder(price: :desc)
    when "stock"
      scope.reorder(stock_quantity: :desc, featured: :desc, created_at: :desc)
    when "newest"
      scope.reorder(created_at: :desc)
    else
      scope
    end
  end

  def average_rating
    reviews.approved.average(:rating).to_f.round(1)
  end

  def in_stock?
    stock_quantity.positive?
  end

  def low_stock?
    in_stock? && stock_quantity <= 5
  end

  def stock_label
    return "Sold out" unless in_stock?
    return "Only #{stock_quantity} left" if low_stock?

    "#{stock_quantity} available"
  end

  private

  def generate_slug
    self.slug = name.to_s.parameterize if slug.blank?
  end

  def generate_sku
    return if sku.present? || name.blank?

    prefix = product_kind.to_s.first(3).presence || "prd"
    self.sku = "#{prefix}-#{name.parameterize.first(18)}-#{SecureRandom.hex(3)}".upcase
  end
end
