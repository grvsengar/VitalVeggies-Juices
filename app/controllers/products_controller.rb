class ProductsController < ApplicationController
  def index
    @categories = Category.active.ordered
    @products = Product.filtered(filter_params)
    @featured_promotion = Promotion.featured.first
    @available_products_count = Product.active.where("stock_quantity > 0").count
  end

  def show
    @product = Product.active.includes(:category).find_by!(slug: params[:id])
    @review = @product.reviews.new
    @reviews = @product.reviews.approved.limit(8)
    @related_products = Product.active.where(category: @product.category).where.not(id: @product.id).limit(4)
  end

  private

  def filter_params
    params.permit(:q, :category, :kind, :organic, :availability, :sort)
  end
end
