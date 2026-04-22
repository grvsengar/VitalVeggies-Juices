module Admin
  class DashboardController < BaseController
    def index
      @metrics = {
        products: Product.count,
        active_orders: Order.where(status: %i[pending confirmed preparing out_for_delivery]).count,
        low_stock: Product.active.where(stock_quantity: 0..5).count,
        revenue: Order.delivered.sum(:total)
      }
      @low_stock_products = Product.active.where(stock_quantity: 0..5).ordered.limit(6)
      @recent_orders = Order.order(created_at: :desc).limit(8)
      @recent_managers = User.managers.limit(6)
    end
  end
end
