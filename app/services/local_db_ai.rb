module LocalDbAi
  ALLOWED_TABLES = %w[
    addresses
    categories
    newsletter_signups
    order_items
    orders
    products
    promotions
    reviews
    users
  ].freeze

  RESTRICTED_COLUMNS = %w[
    password_digest
    password_salt
    invitation_token
    gateway_signature
    gateway_order_id
    gateway_payment_id
    tracking_token
  ].freeze

  DISALLOWED_KEYWORDS = %w[
    alter
    call
    copy
    create
    delete
    do
    drop
    grant
    insert
    revoke
    truncate
    update
  ].freeze

  DISALLOWED_FUNCTIONS = %w[
    pg_sleep
  ].freeze

  class Error < StandardError; end

  class << self
    def config
      Rails.application.config.x.local_db_ai
    end
  end
end
