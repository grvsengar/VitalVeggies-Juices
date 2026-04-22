class NewsletterSignup < ApplicationRecord
  before_validation :normalize_email

  validates :email, presence: true, uniqueness: { case_sensitive: false },
                    format: { with: URI::MailTo::EMAIL_REGEXP }

  private

  def normalize_email
    self.email = email.to_s.downcase.strip
  end
end
