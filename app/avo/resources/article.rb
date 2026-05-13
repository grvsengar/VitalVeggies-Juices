class Avo::Resources::Article < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :image, as: :text, format_using: -> { view_context.link_to("View Image", value.url, target: "_blank", class: "text-blue-500 hover:underline") if value.present? }
    field :video, as: :text, format_using: -> { view_context.link_to("View Video", value.url, target: "_blank", class: "text-blue-500 hover:underline") if value.present? }
    field :title, as: :text
    field :slug, as: :text, only_on: [:show, :edit]
    field :published, as: :boolean
    field :featured, as: :boolean
    field :published_on, as: :date
    field :excerpt, as: :textarea
    field :body, as: :trix
    
    panel "Search Engine Optimization (SEO)" do
      field :meta_title, as: :text
      field :meta_description, as: :textarea
      field :social_caption, as: :textarea
    end
  end

  def actions
    action Avo::Actions::GenerateShortVideo
  end
end
