class PromotionPolicy < ApplicationPolicy
  def index?
    user&.admin?
  end

  def show?
    user&.admin?
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
    [:title, :slug, :description, :discount_kind, :discount_value, :promo_code, :starts_on, :ends_on, :active, :featured]
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.admin? ? scope.all : scope.none
    end
  end
end
