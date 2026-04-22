class UserPolicy < ApplicationPolicy
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
    [:email, :name, :role, :active, :invitation_sent_at, :registered_at, :invited_by_id]
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      user&.admin? ? scope.all : scope.none
    end
  end
end
