module Manager
  class OrdersController < BaseController
    before_action :set_order, only: %i[show update]

    def index
      @orders = Order.includes(order_items: :product).order(created_at: :desc)
      @orders = @orders.where(status: params[:status]) if params[:status].present? && Order.statuses.key?(params[:status])
      if params[:q].present?
        term = "%#{params[:q].strip.downcase}%"
        @orders = @orders.where("LOWER(order_number) LIKE ? OR LOWER(customer_name) LIKE ? OR LOWER(phone) LIKE ?", term, term, term)
      end
    end

    def show; end

    def update
      if @order.update(order_params)
        redirect_to manager_order_path(@order), notice: "Order status updated."
      else
        render :show, status: :unprocessable_entity
      end
    end

    private

    def set_order
      @order = Order.includes(order_items: :product).find(params[:id])
    end

    def order_params
      params.require(:order).permit(:status, :delivery_window)
    end
  end
end
