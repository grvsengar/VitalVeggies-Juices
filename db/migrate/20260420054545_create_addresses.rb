class CreateAddresses < ActiveRecord::Migration[8.0]
  def change
    create_table :addresses do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name
      t.string :recipient_name
      t.string :address_line1
      t.string :address_line2
      t.string :city
      t.string :state
      t.string :postal_code
      t.string :phone
      t.boolean :is_default

      t.timestamps
    end
  end
end
