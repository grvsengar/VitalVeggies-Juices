class ReviewPolicy < ApplicationPolicy
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
    admin_or_manager?
  end

  def destroy?
    user&.admin?
  end

  def permitted_attributes
    [:product_id, :customer_name, :title, :body, :rating, :approved]
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
