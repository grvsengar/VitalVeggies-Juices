module Admin
  class BaseController < ApplicationController
    layout "portal"
    before_action :require_admin!

    private

    def require_admin!
      require_portal_role!(:admin)
    end
  end
end
