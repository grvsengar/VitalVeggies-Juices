module Admin
  class CategoriesController < BaseController
    before_action :set_category, only: %i[edit update destroy]

    def index
      @categories = policy_scope(Category).includes(:products).ordered
      authorize Category
    end

    def new
      @category = Category.new(active: true)
      authorize @category
    end

    def create
      @category = Category.new(category_params)
      authorize @category

      if @category.save
        redirect_to admin_categories_path, notice: "#{@category.name} created."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit
      authorize @category
    end

    def update
      authorize @category

      if @category.update(category_params)
        redirect_to admin_categories_path, notice: "#{@category.name} updated."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      authorize @category

      if @category.destroy
        redirect_to admin_categories_path, notice: "#{@category.name} deleted."
      else
        @category.update(active: false)
        redirect_to admin_categories_path, alert: "#{@category.name} has products, so it was deactivated instead of deleted."
      end
    end

    private

    def set_category
      @category = Category.find(params[:id])
    end

    def category_params
      params.require(:category).permit(policy(@category || Category).permitted_attributes)
    end
  end
end
