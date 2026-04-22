class Avo::Resources::Product < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :name, as: :text, sortable: true
    field :slug, as: :text, hide_on: [:index]
    field :sku, as: :text, sortable: true
    field :description, as: :textarea, hide_on: [:index]
    field :ingredients, as: :textarea, hide_on: [:index]
    field :price, as: :number, sortable: true
    field :stock_quantity, as: :number, sortable: true
    field :featured, as: :boolean
    field :organic, as: :boolean
    field :local, as: :boolean
    field :seasonal, as: :boolean
    field :active, as: :boolean
    field :product_kind, as: :select, enum: ::Product.product_kinds
    field :image, as: :carrier_wave_image, link_to_record: true
    field :category, as: :belongs_to
    field :reviews, as: :has_many
  end
end
