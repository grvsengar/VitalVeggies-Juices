# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 2026_04_21_050749) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "addresses", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name"
    t.string "recipient_name"
    t.string "address_line1"
    t.string "address_line2"
    t.string "city"
    t.string "state"
    t.string "postal_code"
    t.string "phone"
    t.boolean "is_default"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_addresses_on_user_id"
  end

  create_table "articles", force: :cascade do |t|
    t.string "title", null: false
    t.string "slug", null: false
    t.text "excerpt", null: false
    t.text "body", null: false
    t.boolean "published", default: true, null: false
    t.date "published_on"
    t.boolean "featured", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_articles_on_slug", unique: true
  end

  create_table "categories", force: :cascade do |t|
    t.string "name", null: false
    t.string "slug", null: false
    t.text "description"
    t.integer "position", default: 0, null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_categories_on_slug", unique: true
  end

  create_table "faqs", force: :cascade do |t|
    t.string "question", null: false
    t.text "answer", null: false
    t.integer "position", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "newsletter_signups", force: :cascade do |t|
    t.string "email", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_newsletter_signups_on_email", unique: true
  end

  create_table "order_items", force: :cascade do |t|
    t.bigint "order_id", null: false
    t.bigint "product_id", null: false
    t.integer "quantity", null: false
    t.decimal "unit_price", precision: 10, scale: 2, null: false
    t.decimal "line_total", precision: 10, scale: 2, null: false
    t.string "product_name", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["order_id"], name: "index_order_items_on_order_id"
    t.index ["product_id"], name: "index_order_items_on_product_id"
  end

  create_table "orders", force: :cascade do |t|
    t.string "order_number", null: false
    t.string "customer_name", null: false
    t.string "email", null: false
    t.string "phone", null: false
    t.string "address_line1", null: false
    t.string "address_line2"
    t.string "city", null: false
    t.string "state", null: false
    t.string "postal_code", null: false
    t.text "notes"
    t.integer "status", default: 0, null: false
    t.decimal "subtotal", precision: 10, scale: 2, null: false
    t.decimal "discount_total", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "delivery_fee", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "total", precision: 10, scale: 2, null: false
    t.string "payment_method", null: false
    t.string "payment_status", default: "pending", null: false
    t.string "delivery_window"
    t.string "tracking_token", null: false
    t.string "coupon_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.bigint "address_id"
    t.index ["address_id"], name: "index_orders_on_address_id"
    t.index ["order_number"], name: "index_orders_on_order_number", unique: true
    t.index ["tracking_token"], name: "index_orders_on_tracking_token", unique: true
    t.index ["user_id"], name: "index_orders_on_user_id"
  end

  create_table "products", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.string "name", null: false
    t.string "slug", null: false
    t.string "sku", null: false
    t.text "description"
    t.text "ingredients"
    t.decimal "price", precision: 10, scale: 2, null: false
    t.integer "stock_quantity", default: 0, null: false
    t.boolean "featured", default: false, null: false
    t.boolean "organic", default: false, null: false
    t.boolean "local", default: false, null: false
    t.boolean "seasonal", default: false, null: false
    t.boolean "active", default: true, null: false
    t.integer "product_kind", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "image"
    t.index ["category_id"], name: "index_products_on_category_id"
    t.index ["sku"], name: "index_products_on_sku", unique: true
    t.index ["slug"], name: "index_products_on_slug", unique: true
  end

  create_table "promotions", force: :cascade do |t|
    t.string "title", null: false
    t.string "slug", null: false
    t.text "description"
    t.integer "discount_kind", default: 0, null: false
    t.decimal "discount_value", precision: 10, scale: 2, null: false
    t.string "promo_code"
    t.date "starts_on", null: false
    t.date "ends_on", null: false
    t.boolean "active", default: true, null: false
    t.boolean "featured", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["promo_code"], name: "index_promotions_on_promo_code", unique: true
    t.index ["slug"], name: "index_promotions_on_slug", unique: true
  end

  create_table "reviews", force: :cascade do |t|
    t.bigint "product_id", null: false
    t.string "customer_name", null: false
    t.string "title", null: false
    t.text "body", null: false
    t.integer "rating", null: false
    t.boolean "approved", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_reviews_on_product_id"
  end

  create_table "testimonials", force: :cascade do |t|
    t.string "customer_name", null: false
    t.string "role"
    t.text "quote", null: false
    t.integer "rating", null: false
    t.boolean "featured", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.string "email", null: false
    t.string "name"
    t.integer "role", default: 2, null: false
    t.string "password_digest"
    t.string "password_salt"
    t.boolean "active", default: true, null: false
    t.string "invitation_token"
    t.datetime "invitation_sent_at"
    t.datetime "registered_at"
    t.bigint "invited_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["invitation_token"], name: "index_users_on_invitation_token", unique: true
    t.index ["invited_by_id"], name: "index_users_on_invited_by_id"
  end

  add_foreign_key "addresses", "users"
  add_foreign_key "order_items", "orders"
  add_foreign_key "order_items", "products"
  add_foreign_key "orders", "addresses"
  add_foreign_key "orders", "users"
  add_foreign_key "products", "categories"
  add_foreign_key "reviews", "products"
  add_foreign_key "users", "users", column: "invited_by_id"
end
