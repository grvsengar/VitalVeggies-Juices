class AiQueryPolicy < ApplicationPolicy
  def show?
    portal_user?
  end

  def create?
    portal_user?
  end

  private

  def portal_user?
    user&.admin? || user&.manager?
  end
end
