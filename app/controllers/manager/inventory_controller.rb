module Manager
  class InventoryController < BaseController
    before_action :set_product, only: %i[edit update]

    def index
      @products = Product.includes(:category).order(stock_quantity: :asc, created_at: :desc)
      @products = @products.search_by_name_and_description(params[:q]) if params[:q].present?
      @products = @products.where(category_id: params[:category_id]) if params[:category_id].present?
      @products = @products.where(stock_quantity: 0) if params[:stock] == "sold_out"
      @products = @products.where(stock_quantity: 1..5) if params[:stock] == "low_stock"
      @products = @products.where("stock_quantity > 5") if params[:stock] == "healthy"
      @categories = Category.ordered
    end

    def edit; end

    def update
      if @product.update(product_params)
        redirect_to manager_inventory_index_path, notice: "#{@product.name} inventory updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    private

    def set_product
      @product = Product.find(params[:id])
    end

    def product_params
      params.require(:product).permit(:stock_quantity, :active)
    end
  end
end
