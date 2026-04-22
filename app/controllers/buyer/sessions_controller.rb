module Buyer
  class SessionsController < ApplicationController
    layout "portal"

    def new
      @role = :buyer
      @hide_portal_nav = true
    end

    def create
      user = User.find_by(email: params[:email].to_s.strip.downcase, role: :buyer, active: true)

      if user&.authenticate(params[:password])
        start_user_session(user)
        redirect_to buyer_root_path, notice: "Signed in to buyer account."
      else
        @role = :buyer
        @hide_portal_nav = true
        flash.now[:alert] = "Invalid buyer credentials."
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      reset_user_session
      redirect_to buyer_login_path, notice: "Signed out."
    end
  end
end
