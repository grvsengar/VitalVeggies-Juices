class OrderItemPolicy < ApplicationPolicy
  def index?
    admin_or_manager?
  end

  def show?
    admin_or_manager?
  end

  def create?
    user&.admin?
  end

  def update?
    user&.admin?
  end

  def destroy?
    user&.admin?
  end

  def permitted_attributes
    [:order_id, :product_id, :product_name, :quantity, :unit_price, :line_total]
  end

  private

  def admin_or_manager?
    user&.admin? || user&.manager?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.admin? || user&.manager? ? scope.all : scope.none
    end
  end
end
