module Manager
  class SessionsController < ApplicationController
    layout "portal"

    def new
      @role = :manager
      @hide_portal_nav = true
    end

    def create
      user = User.find_by(email: params[:email].to_s.strip.downcase, role: :manager, active: true)

      if user&.authenticate(params[:password])
        start_user_session(user)
        redirect_to manager_root_path, notice: "Signed in to manager portal."
      else
        @role = :manager
        @hide_portal_nav = true
        flash.now[:alert] = "Invalid manager credentials or registration is incomplete."
        render :new, status: :unprocessable_entity
      end
    end

    def destroy
      reset_user_session
      redirect_to manager_login_path, notice: "Signed out."
    end
  end
end
