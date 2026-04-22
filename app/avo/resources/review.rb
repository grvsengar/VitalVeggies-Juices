class Avo::Resources::Review < Avo::BaseResource
  self.title = :title
  self.includes = [:product]

  def fields
    field :id, as: :id
    field :product, as: :belongs_to
    field :customer_name, as: :text, sortable: true
    field :title, as: :text, sortable: true
    field :body, as: :textarea, hide_on: [:index]
    field :rating, as: :number, sortable: true
    field :approved, as: :boolean
    field :created_at, as: :date_time, only_on: [:show]
    field :updated_at, as: :date_time, only_on: [:show]
  end
end
