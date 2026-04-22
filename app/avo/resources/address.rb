class Avo::Resources::Address < Avo::BaseResource
  self.title = :recipient_name
  self.includes = [:user]

  def fields
    field :id, as: :id
    field :user, as: :belongs_to
    field :name, as: :text, hide_on: [:index]
    field :recipient_name, as: :text, sortable: true
    field :address_line1, as: :text
    field :address_line2, as: :text, hide_on: [:index]
    field :city, as: :text, sortable: true
    field :state, as: :text, sortable: true
    field :postal_code, as: :text
    field :phone, as: :text
    field :is_default, as: :boolean
    field :orders, as: :has_many
  end
end
