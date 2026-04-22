class ApplicationController < ActionController::Base
  include ::Pundit::Authorization

  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  before_action :set_current_cart

  helper_method :current_cart, :current_promotion, :current_user, :portal_signed_in?, :buyer_signed_in?

  private

  def set_current_cart
    session[:cart] ||= {}
    @current_cart = Cart.new(session)
  end

  def current_cart
    @current_cart
  end

  def current_promotion
    return if session[:coupon_code].blank?

    @current_promotion ||= Promotion.current.find_by("LOWER(promo_code) = ?", session[:coupon_code].downcase)
  end

  def current_user
    return if session[:user_id].blank?

    @current_user ||= User.find_by(id: session[:user_id], active: true)
  end

  def portal_signed_in?(role = nil)
    return false unless current_user&.admin? || current_user&.manager?
    return true if role.blank?

    current_user.role == role.to_s
  end

  def buyer_signed_in?
    current_user&.buyer?
  end

  def require_portal_role!(role)
    return if portal_signed_in?(role)

    reset_user_session
    redirect_to public_send("#{role}_login_path"), alert: "Please sign in to continue."
  end

  def require_buyer!
    return if buyer_signed_in?

    reset_user_session
    session[:return_to] = request.fullpath
    redirect_to login_path, alert: "Please sign in to complete your order."
  end

  def start_user_session(user)
    session[:user_id] = user.id
    @current_user = user
  end

  def reset_user_session
    session.delete(:user_id)
    @current_user = nil
  end

  def user_not_authorized
    redirect_back fallback_location: root_path, alert: "You are not authorized to perform that action."
  end
end
