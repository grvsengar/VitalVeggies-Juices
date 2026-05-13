class AddRazorpayFieldsToOrders < ActiveRecord::Migration[8.0]
  def change
    change_table :orders, bulk: true do |t|
      t.string :payment_provider
      t.string :gateway_order_id
      t.string :gateway_payment_id
      t.string :gateway_signature
      t.string :gateway_payment_method
      t.datetime :paid_at
    end

    add_index :orders, :gateway_order_id, unique: true
    add_index :orders, :gateway_payment_id, unique: true
  end
end
