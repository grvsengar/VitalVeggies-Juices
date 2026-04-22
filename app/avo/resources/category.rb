class Avo::Resources::Category < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :name, as: :text, sortable: true
    field :slug, as: :text, hide_on: [:index]
    field :description, as: :textarea, hide_on: [:index]
    field :position, as: :number, sortable: true
    field :active, as: :boolean
    field :products, as: :has_many
  end
end
