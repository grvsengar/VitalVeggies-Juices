class Avo::Resources::OrderItem < Avo::BaseResource
  self.title = :product_name
  self.includes = %i[order product]

  def fields
    field :id, as: :id
    field :order, as: :belongs_to
    field :product, as: :belongs_to
    field :product_name, as: :text, sortable: true
    field :quantity, as: :number
    field :unit_price, as: :number
    field :line_total, as: :number
  end
end
