module Admin
  class ProductsController < BaseController
    before_action :set_product, only: %i[edit update destroy]

    def index
      @products = policy_scope(Product).includes(:category).order(created_at: :desc)
      authorize Product
    end

    def new
      @product = Product.new(active: true, stock_quantity: 0)
      authorize @product
    end

    def create
      @product = Product.new(product_params)
      authorize @product

      if @product.save
        redirect_to admin_products_path, notice: "#{@product.name} created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @product
    end

    def update
      authorize @product

      if @product.update(product_params)
        redirect_to admin_products_path, notice: "#{@product.name} updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @product

      if @product.destroy
        redirect_to admin_products_path, notice: "#{@product.name} deleted."
      else
        @product.update(active: false)
        redirect_to admin_products_path, alert: "#{@product.name} has order history, so it was deactivated instead of deleted."
      end
    end

    private

    def set_product
      @product = Product.find(params[:id])
    end

    def product_params
      params.require(:product).permit(policy(@product || Product).permitted_attributes)
    end
  end
end
