class CreatePromotions < ActiveRecord::Migration[8.0]
  def change
    create_table :promotions do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.text :description
      t.integer :discount_kind, default: 0, null: false
      t.decimal :discount_value, precision: 10, scale: 2, null: false
      t.string :promo_code
      t.date :starts_on, null: false
      t.date :ends_on, null: false
      t.boolean :active, default: true, null: false
      t.boolean :featured, default: false, null: false

      t.timestamps
    end

    add_index :promotions, :slug, unique: true
    add_index :promotions, :promo_code, unique: true
  end
end
