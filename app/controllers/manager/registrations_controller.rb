module Manager
  class RegistrationsController < ApplicationController
    layout "portal"
    before_action :set_manager

    def edit
      @hide_site_chrome = true
      @hide_portal_nav = true
    end

    def update
      @hide_site_chrome = true
      @hide_portal_nav = true
      @manager.complete_manager_registration!(registration_params)
      redirect_to login_path, notice: "Registration complete. You can now sign in to the manager portal."
    rescue ActiveRecord::RecordInvalid
      render :edit, status: :unprocessable_entity
    end

    private

    def set_manager
      @manager = User.find_by!(role: :manager, invitation_token: params[:token], active: true)
    end

    def registration_params
      params.require(:user).permit(:name, :password, :password_confirmation)
    end
  end
end
