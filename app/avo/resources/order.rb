class Avo::Resources::Order < Avo::BaseResource
  self.title = :order_number
  self.includes = %i[user address]

  def fields
    field :id, as: :id
    field :order_number, as: :text, sortable: true
    field :customer_name, as: :text, sortable: true
    field :email, as: :text
    field :phone, as: :text
    field :address_line1, as: :text, hide_on: [:index]
    field :address_line2, as: :text, hide_on: [:index]
    field :city, as: :text
    field :state, as: :text
    field :postal_code, as: :text
    field :notes, as: :textarea, hide_on: [:index]
    field :status, as: :select, enum: ::Order.statuses
    field :subtotal, as: :number, sortable: true
    field :discount_total, as: :number
    field :delivery_fee, as: :number
    field :total, as: :number, sortable: true
    field :payment_method, as: :text
    field :payment_status, as: :text
    field :delivery_window, as: :text, hide_on: [:index]
    field :tracking_token, as: :text, only_on: [:show]
    field :coupon_code, as: :text, hide_on: [:index]
    field :user, as: :belongs_to
    field :address, as: :belongs_to
    field :order_items, as: :has_many
  end
end
