module Manager
  class CategoriesController < BaseController
    def index
      @categories = Category.includes(:products).ordered
    end
  end
end
