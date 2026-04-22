class CreateOrders < ActiveRecord::Migration[8.0]
  def change
    create_table :orders do |t|
      t.string :order_number, null: false
      t.string :customer_name, null: false
      t.string :email, null: false
      t.string :phone, null: false
      t.string :address_line1, null: false
      t.string :address_line2
      t.string :city, null: false
      t.string :state, null: false
      t.string :postal_code, null: false
      t.text :notes
      t.integer :status, default: 0, null: false
      t.decimal :subtotal, precision: 10, scale: 2, null: false
      t.decimal :discount_total, precision: 10, scale: 2, default: 0, null: false
      t.decimal :delivery_fee, precision: 10, scale: 2, default: 0, null: false
      t.decimal :total, precision: 10, scale: 2, null: false
      t.string :payment_method, null: false
      t.string :payment_status, default: "pending", null: false
      t.string :delivery_window
      t.string :tracking_token, null: false
      t.string :coupon_code

      t.timestamps
    end

    add_index :orders, :order_number, unique: true
    add_index :orders, :tracking_token, unique: true
  end
end
