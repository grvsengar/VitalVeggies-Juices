class OrderPolicy < ApplicationPolicy
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
    [:user_id, :address_id, :order_number, :customer_name, :email, :phone, :address_line1, :address_line2, :city, :state, :postal_code, :notes, :status, :subtotal, :discount_total, :delivery_fee, :total, :payment_method, :payment_status, :delivery_window, :tracking_token, :coupon_code]
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
