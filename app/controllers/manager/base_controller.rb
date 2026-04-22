module Manager
  class BaseController < ApplicationController
    layout "portal"
    before_action :require_manager!

    private

    def require_manager!
      require_portal_role!(:manager)
    end
  end
end
