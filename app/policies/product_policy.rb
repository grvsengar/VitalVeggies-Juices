class ProductPolicy < ApplicationPolicy
  def index?
    admin_or_manager?
  end

  def show?
    admin_or_manager?
  end

  def create?
    admin_or_manager?
  end

  def update?
    admin_or_manager?
  end

  def destroy?
    user&.admin?
  end

  def permitted_attributes
    if user&.admin?
      [:category_id, :name, :slug, :sku, :description, :ingredients, :price, :stock_quantity, :featured, :organic, :local, :seasonal, :active, :product_kind, :image, :image_cache, :remove_image]
    elsif user&.manager?
      [:category_id, :name, :slug, :sku, :description, :ingredients, :price, :stock_quantity, :featured, :organic, :local, :seasonal, :active, :product_kind, :image, :image_cache, :remove_image]
    else
      []
    end
  end

  private

  def admin_or_manager?
    user&.admin? || user&.manager?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user&.admin? || user&.manager?
        scope.all
      else
        scope.none
      end
    end
  end
end
