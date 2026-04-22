class RegistrationsController < ApplicationController
  before_action { @hide_site_chrome = true }
  def new
    @user = User.new
  end

  def create
    @user = User.new(registration_params)
    @user.role = :buyer
    @user.active = true
    @user.registered_at = Time.current

    if @user.save
      start_user_session(@user)
      redirect_to root_path, notice: "Account created successfully! Welcome to #{business_details[:name]}."
    else
      render :new, status: :unprocessable_entity
    end
  end

  private

  def registration_params
    params.require(:user).permit(:name, :email, :password, :password_confirmation)
  end
end
