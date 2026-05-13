module Manager
  class DashboardController < BaseController
    def index
      @metrics = Order.manager_metrics
      @analytics = Order.manager_analytics
      @low_stock_products = Product.active.includes(:category).where(stock_quantity: 0..5).ordered.limit(6)
      @recent_orders = Order.dashboard_recent_orders
    end
  end
end
