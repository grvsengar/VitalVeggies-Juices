module Manager
  class ProductsController < BaseController
    def index
      @products = policy_scope(Product).includes(:category).order(active: :desc, stock_quantity: :asc, created_at: :desc)
      @products = @products.search_by_name_and_description(params[:q]) if params[:q].present?
      @products = @products.where(category_id: params[:category_id]) if params[:category_id].present?
      @products = @products.where(product_kind: params[:kind]) if params[:kind].present?
      @products = @products.where(active: params[:status] == "active") if params[:status].in?(%w[active hidden])
      @categories = Category.ordered
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
        redirect_to manager_products_path, notice: "#{@product.name} created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    private

    def product_params
      params.require(:product).permit(policy(@product || Product).permitted_attributes)
    end
  end
end
