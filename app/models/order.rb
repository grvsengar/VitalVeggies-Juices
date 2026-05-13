class Order < ApplicationRecord
  ONLINE_PAYMENT_METHOD = "online_gateway".freeze

  belongs_to :user, optional: true
  belongs_to :address, optional: true
  has_many :order_items, dependent: :destroy

  scope :recent_first, -> { order(created_at: :desc) }
  scope :open_fulfilment, -> { where(status: %i[pending confirmed preparing out_for_delivery]) }

  enum :status, {
    pending: 0,
    confirmed: 1,
    preparing: 2,
    out_for_delivery: 3,
    delivered: 4,
    cancelled: 5
  }, default: :pending

  validates :customer_name, :email, :phone, :address_line1, :city, :state, :postal_code, :payment_method, presence: true
  validates :order_number, :tracking_token, presence: true, uniqueness: true

  before_validation :assign_identifiers
  after_create_commit :broadcast_live_order_created
  after_update_commit :broadcast_live_order_updated, if: :live_view_changed?

  class << self
    def manager_metrics
      {
        pending_orders: where(status: %i[pending confirmed preparing]).count,
        out_for_delivery: out_for_delivery.count,
        low_stock: Product.active.where(stock_quantity: 0..5).count,
        sold_out: Product.active.where(stock_quantity: 0).count,
        active_products: Product.active.count
      }
    end

    def dashboard_recent_orders(limit: 8)
      includes(order_items: :product).recent_first.limit(limit)
    end

    def manager_analytics(days_back: 7)
      start_date = (days_back - 1).days.ago.to_date
      dates = (start_date..Date.current).to_a
      time_range = start_date.beginning_of_day..Time.current

      order_totals = where(created_at: time_range).group("DATE(created_at)").count.transform_keys { |value| value.to_date }
      revenue_totals = where(created_at: time_range).group("DATE(created_at)").sum(:total).transform_keys { |value| value.to_date }
      top_products = OrderItem.joins(:product, :order)
                              .where(orders: { created_at: time_range })
                              .group("products.name")
                              .sum(:quantity)
                              .sort_by { |_name, quantity| -quantity }
                              .first(5)

      {
        labels: dates.map { |date| date.strftime("%b %-d") },
        order_counts: dates.map { |date| order_totals.fetch(date, 0) },
        revenue_points: dates.map { |date| revenue_totals.fetch(date, 0).to_f.round(2) },
        revenue_total: revenue_totals.values.sum.to_f.round(2),
        top_products: top_products.map { |name, quantity| { name:, quantity: } }
      }
    end
  end

  def full_address
    [ address_line1, address_line2, city, state, postal_code ].compact_blank.join(", ")
  end

  def online_gateway?
    payment_method == ONLINE_PAYMENT_METHOD
  end

  def paid?
    payment_status == "paid"
  end

  def total_in_subunits
    (total.to_d * 100).round.to_i
  end

  def gateway_contact
    digits = phone.to_s.gsub(/\D/, "")
    return if digits.blank?

    if digits.start_with?("91") && digits.length == 12
      "+#{digits}"
    elsif digits.length == 10
      "+91#{digits}"
    else
      "+#{digits}"
    end
  end

  private

  def live_view_changed?
    (previous_changes.keys & %w[status payment_status delivery_window total customer_name phone notes]).any?
  end

  def assign_identifiers
    self.order_number ||= "VVJ-#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.hex(3).upcase}"
    self.tracking_token ||= SecureRandom.alphanumeric(10).upcase
  end

  def broadcast_live_order_created
    broadcast_prepend_to "manager_orders",
                         target: "manager_orders_rows",
                         partial: "manager/orders/order_row",
                         locals: { order: self, highlight: true }

    broadcast_prepend_to "admin_orders",
                         target: "admin_orders_rows",
                         partial: "admin/orders/order_row",
                         locals: { order: self, highlight: true }

    broadcast_prepend_to "manager_dashboard",
                         target: "manager_dashboard_recent_orders_rows",
                         partial: "manager/dashboard/recent_order_row",
                         locals: { order: self, highlight: true }

    broadcast_manager_dashboard_refresh
  end

  def broadcast_live_order_updated
    broadcast_replace_to "manager_orders",
                         target: ActionView::RecordIdentifier.dom_id(self, :manager_order_row),
                         partial: "manager/orders/order_row",
                         locals: { order: self, highlight: false }

    broadcast_replace_to "admin_orders",
                         target: ActionView::RecordIdentifier.dom_id(self, :admin_order_row),
                         partial: "admin/orders/order_row",
                         locals: { order: self, highlight: false }

    broadcast_replace_to "manager_dashboard",
                         target: ActionView::RecordIdentifier.dom_id(self, :dashboard_order_row),
                         partial: "manager/dashboard/recent_order_row",
                         locals: { order: self, highlight: false }

    broadcast_manager_dashboard_refresh
  end

  def broadcast_manager_dashboard_refresh
    analytics = self.class.manager_analytics

    broadcast_replace_to "manager_dashboard",
                         target: "manager_dashboard_metrics",
                         partial: "manager/dashboard/metrics",
                         locals: { metrics: self.class.manager_metrics, analytics: analytics }

    broadcast_replace_to "manager_dashboard",
                         target: "manager_dashboard_analytics",
                         partial: "manager/dashboard/analytics",
                         locals: { analytics: analytics }
  end
end
