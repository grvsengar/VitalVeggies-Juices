module Admin
  class SessionsController < ApplicationController
    layout "portal"

    def new
      @role = :admin
      @hide_portal_nav = true
    end

    def create
      user = User.find_by(email: params[:email].to_s.strip.downcase, role: :admin, active: true)

      if user&.authenticate(params[:password])
        start_user_session(user)
        redirect_to admin_root_path, notice: "Signed in to admin portal."
      else
        @role = :admin
        @hide_portal_nav = true
        flash.now[:alert] = "Invalid admin credentials."
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      reset_user_session
      redirect_to admin_login_path, notice: "Signed out."
    end
  end
end
