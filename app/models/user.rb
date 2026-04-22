class User < ApplicationRecord
  ROLES = {
    admin: 0,
    manager: 1,
    buyer: 2
  }.freeze

  RESPONSIBILITIES = {
    admin: [
      "Manage catalog, pricing, and promotions",
      "Create manager accounts and send invitation emails",
      "Review all orders, payments, and customer activity"
    ],
    manager: [
      "Track daily orders and move delivery statuses",
      "Update stock levels and availability",
      "Respond to low-stock and fulfilment issues"
    ],
    buyer: [
      "Access saved account details",
      "Review order history matched to your email",
      "Track orders from one account area"
    ]
  }.freeze

  enum :role, ROLES, default: :buyer

  belongs_to :invited_by, class_name: "User", optional: true
  has_many :invited_users, class_name: "User", foreign_key: :invited_by_id, dependent: :nullify
  has_many :addresses, dependent: :destroy
  has_many :orders, dependent: :nullify

  before_validation :normalize_email
  before_validation :ensure_manager_invitation_token

  validates :email, presence: true, uniqueness: { case_sensitive: false }
  validates :name, presence: true, if: :registered?
  validates :password_digest, presence: true, if: :registered?
  validates :password, length: { minimum: 8 }, allow_nil: true
  validate :password_confirmation_matches

  attr_reader :password, :password_confirmation

  scope :managers, -> { where(role: :manager).order(created_at: :desc) }
  scope :buyers, -> { where(role: :buyer).order(created_at: :desc) }

  def password=(raw_password)
    @password = raw_password
    return if raw_password.blank?

    self.password_salt = SecureRandom.hex(16)
    self.password_digest = self.class.digest_password(raw_password, password_salt)
  end

  def password_confirmation=(raw_confirmation)
    @password_confirmation = raw_confirmation
  end

  def authenticate(raw_password)
    return false if password_digest.blank? || password_salt.blank? || raw_password.blank?

    ActiveSupport::SecurityUtils.secure_compare(
      password_digest,
      self.class.digest_password(raw_password, password_salt)
    )
  end

  def registered?
    registered_at.present?
  end

  def invited_manager?
    manager? && !registered?
  end

  def responsibilities
    RESPONSIBILITIES.fetch(role.to_sym)
  end

  def invite_url
    Rails.application.routes.url_helpers.manager_register_url(invitation_token)
  end

  def prepare_manager_invitation!(inviter:)
    self.role = :manager
    self.invited_by = inviter
    self.registered_at = nil
    self.active = true if active.nil?
    self.invitation_token = SecureRandom.urlsafe_base64(24)
    self.invitation_sent_at = Time.current
    save!
  end

  def complete_manager_registration!(attributes)
    update!(
      name: attributes[:name],
      password: attributes[:password],
      password_confirmation: attributes[:password_confirmation],
      registered_at: Time.current,
      invitation_token: nil
    )
  end

  def self.digest_password(password, salt)
    Digest::SHA256.hexdigest("#{salt}::#{password}")
  end

  private

  def normalize_email
    self.email = email.to_s.strip.downcase
  end

  def ensure_manager_invitation_token
    return unless manager? && !registered? && invitation_token.blank?

    self.invitation_token = SecureRandom.urlsafe_base64(24)
  end

  def password_confirmation_matches
    return if password.nil?
    return if password == password_confirmation

    errors.add(:password_confirmation, "does not match")
  end
end
