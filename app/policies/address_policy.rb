class AddressPolicy < ApplicationPolicy
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
    [:user_id, :name, :recipient_name, :address_line1, :address_line2, :city, :state, :postal_code, :phone, :is_default]
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
