class AddUserAndAddressToOrders < ActiveRecord::Migration[8.0]
  def change
    add_reference :orders, :user, null: true, foreign_key: true
    add_reference :orders, :address, null: true, foreign_key: true
  end
end
