class Avo::Resources::User < Avo::BaseResource
  # self.includes = []
  # self.attachments = []
  # self.search = {
  #   query: -> { query.ransack(id_eq: q, m: "or").result(distinct: false) }
  # }

  def fields
    field :id, as: :id
    field :email, as: :text
    field :name, as: :text
    field :role, as: :select, enum: ::User.roles
    field :password_salt, as: :text, only_on: []
    field :active, as: :boolean
    field :invitation_token, as: :text, only_on: []
    field :invitation_sent_at, as: :date_time, hide_on: [:index]
    field :registered_at, as: :date_time, hide_on: [:index]
    field :invited_by_id, as: :number, only_on: []
    field :invited_by, as: :belongs_to
    field :invited_users, as: :has_many
    field :addresses, as: :has_many
    field :orders, as: :has_many
  end
end
