module Manager
  class DashboardController < BaseController
    def index
      @metrics = {
        pending_orders: Order.where(status: %i[pending confirmed preparing]).count,
        out_for_delivery: Order.out_for_delivery.count,
        low_stock: Product.active.where(stock_quantity: 0..5).count,
        sold_out: Product.active.where(stock_quantity: 0).count,
        active_products: Product.active.count
      }
      @low_stock_products = Product.active.includes(:category).where(stock_quantity: 0..5).ordered.limit(6)
      @active_orders = Order.where(status: %i[pending confirmed preparing out_for_delivery]).order(created_at: :desc).limit(8)
    end
  end
end
