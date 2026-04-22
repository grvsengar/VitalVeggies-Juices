class NewsletterSignupsController < ApplicationController
  def create
    signup = NewsletterSignup.new(newsletter_signup_params.merge(active: true))

    if signup.save
      redirect_back fallback_location: root_path, notice: "You are subscribed for fresh offers and updates."
    else
      redirect_back fallback_location: root_path, alert: signup.errors.full_messages.to_sentence
    end
  end

  private

  def newsletter_signup_params
    params.require(:newsletter_signup).permit(:email)
  end
end
