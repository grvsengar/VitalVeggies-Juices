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
    field :password_salt, as: :text, hide_on: %i[index show new edit]
    field :active, as: :boolean
    field :invitation_token, as: :text, hide_on: %i[index show new edit]
    field :invitation_sent_at, as: :date_time, only_on: [:show]
    field :registered_at, as: :date_time, only_on: [:show]
    field :invited_by_id, as: :number, hide_on: %i[index show new edit]
    field :invited_by, as: :belongs_to, only_on: [:show]
    field :invited_users, as: :has_many, only_on: [:show]
    field :addresses, as: :has_many, only_on: [:show]
    field :orders, as: :has_many, only_on: [:show]
  end

  def actions
    action Avo::Actions::ResendInvitation
  end
end
