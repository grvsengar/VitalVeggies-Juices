module Buyer
  class BaseController < ApplicationController
    layout "portal"
    before_action :require_buyer!
  end
end
