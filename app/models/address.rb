class Address < ApplicationRecord
  belongs_to :user
  has_many :orders, dependent: :nullify

  validates :recipient_name, :address_line1, :city, :state, :postal_code, :phone, presence: true

  def full_address
    [ address_line1, address_line2, city, state, postal_code ].compact_blank.join(", ")
  end
end
