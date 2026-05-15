module Portal
  class BaseController < ApplicationController
    layout "portal"
    before_action :require_portal_user!

    private

    def require_portal_user!
      return if portal_signed_in?

      reset_user_session
      session[:return_to] = request.fullpath
      redirect_to login_path, alert: "Please sign in to continue."
    end
  end
end
