class SessionsController < ApplicationController
  before_action { @hide_site_chrome = true }
  def new
    redirect_to root_path if current_user
  end

  def create
    user = User.find_by(email: params[:email].to_s.strip.downcase, active: true)

    if user&.authenticate(params[:password])
      start_user_session(user)
      
      flash[:notice] = "Welcome back, #{user.name}!"
      
      if user.admin?
        redirect_to "/avo"
      elsif user.manager?
        redirect_to manager_root_path
      else
        redirect_back_or_to root_path
      end
    else
      flash.now[:alert] = "Invalid email or password."
      render :new, status: :unprocessable_entity
    end
  end

  def destroy
    reset_user_session
    redirect_to root_path, notice: "Signed out successfully."
  end

  private

  def redirect_back_or_to(fallback)
    redirect_to session[:return_to] || fallback
    session.delete(:return_to)
  end
end
