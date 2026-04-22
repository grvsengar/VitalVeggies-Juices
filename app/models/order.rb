class Order < ApplicationRecord
  belongs_to :user, optional: true
  belongs_to :address, optional: true
  has_many :order_items, dependent: :destroy

  enum :status, {
    pending: 0,
    confirmed: 1,
    preparing: 2,
    out_for_delivery: 3,
    delivered: 4,
    cancelled: 5
  }, default: :pending

  validates :customer_name, :email, :phone, :address_line1, :city, :state, :postal_code, :payment_method, presence: true
  validates :order_number, :tracking_token, presence: true, uniqueness: true

  before_validation :assign_identifiers

  def full_address
    [ address_line1, address_line2, city, state, postal_code ].compact_blank.join(", ")
  end

  private

  def assign_identifiers
    self.order_number ||= "VVJ-#{Time.current.strftime('%Y%m%d')}-#{SecureRandom.hex(3).upcase}"
    self.tracking_token ||= SecureRandom.alphanumeric(10).upcase
  end
end
