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
  after_update_commit :broadcast_live_inventory, if: :live_inventory_changed?

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

  def available_for_purchase?
    active? && in_stock?
  end

  def low_stock?
    in_stock? && stock_quantity <= 5
  end

  def stock_label
    return "Unavailable" unless active?
    return "Sold out" unless in_stock?
    return "Only #{stock_quantity} left" if low_stock?

    "#{stock_quantity} available"
  end

  private

  def live_inventory_changed?
    (previous_changes.keys & %w[name slug sku price stock_quantity active category_id product_kind image description organic local seasonal]).any?
  end

  def broadcast_live_inventory
    broadcast_replace_to "inventory",
                         target: ActionView::RecordIdentifier.dom_id(self, :stock_badge),
                         partial: "shared/product_stock_badge",
                         locals: { product: self }

    broadcast_replace_to "inventory",
                         target: ActionView::RecordIdentifier.dom_id(self, :card_purchase),
                         partial: "shared/product_card_purchase",
                         locals: { product: self }

    broadcast_replace_to "inventory",
                         target: ActionView::RecordIdentifier.dom_id(self, :detail_purchase),
                         partial: "products/detail_purchase",
                         locals: { product: self }

    broadcast_replace_to "inventory",
                         target: ActionView::RecordIdentifier.dom_id(self, :admin_product_card),
                         partial: "admin/products/product_card",
                         locals: { product: self }

    broadcast_replace_to "inventory",
                         target: ActionView::RecordIdentifier.dom_id(self, :manager_inventory_row),
                         partial: "manager/inventory/product_row",
                         locals: { product: self }

    broadcast_replace_to "inventory",
                         target: ActionView::RecordIdentifier.dom_id(self, :manager_product_row),
                         partial: "manager/products/product_row",
                         locals: { product: self }

    broadcast_replace_to "inventory",
                         target: "admin_dashboard_metrics",
                         partial: "admin/dashboard/metrics"

    broadcast_replace_to "inventory",
                         target: "admin_low_stock_watchlist",
                         partial: "admin/dashboard/low_stock_watchlist"

    broadcast_replace_to "inventory",
                         target: "manager_dashboard_metrics",
                         partial: "manager/dashboard/metrics"

    broadcast_replace_to "inventory",
                         target: "manager_low_stock_alerts",
                         partial: "manager/dashboard/low_stock_alerts"
  end

  def generate_slug
    self.slug = name.to_s.parameterize if slug.blank?
  end

  def generate_sku
    return if sku.present? || name.blank?

    prefix = product_kind.to_s.first(3).presence || "prd"
    self.sku = "#{prefix}-#{name.parameterize.first(18)}-#{SecureRandom.hex(3)}".upcase
  end
end
