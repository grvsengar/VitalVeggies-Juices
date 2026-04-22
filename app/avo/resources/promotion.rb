class Avo::Resources::Promotion < Avo::BaseResource
  self.title = :title

  def fields
    field :id, as: :id
    field :title, as: :text, sortable: true
    field :slug, as: :text, hide_on: [:index]
    field :description, as: :textarea, hide_on: [:index]
    field :discount_kind, as: :select, enum: ::Promotion.discount_kinds
    field :discount_value, as: :number, sortable: true
    field :promo_code, as: :text, sortable: true
    field :starts_on, as: :date
    field :ends_on, as: :date
    field :active, as: :boolean
    field :featured, as: :boolean
  end
end
