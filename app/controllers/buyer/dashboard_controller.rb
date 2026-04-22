module Buyer
  class DashboardController < BaseController
    def index
      @orders = Order.where("LOWER(email) = ?", current_user.email.downcase).order(created_at: :desc).limit(10)
    end
  end
end
