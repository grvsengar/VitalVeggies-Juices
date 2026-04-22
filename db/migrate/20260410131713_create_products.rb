class CreateProducts < ActiveRecord::Migration[8.0]
  def change
    create_table :products do |t|
      t.references :category, null: false, foreign_key: true
      t.string :name
      t.string :slug
      t.string :sku
      t.text :description
      t.text :ingredients
      t.decimal :price, precision: 10, scale: 2, null: false
      t.integer :stock_quantity, default: 0, null: false
      t.boolean :featured, default: false, null: false
      t.boolean :organic, default: false, null: false
      t.boolean :local, default: false, null: false
      t.boolean :seasonal, default: false, null: false
      t.boolean :active, default: true, null: false
      t.integer :product_kind, default: 0, null: false

      t.timestamps
    end

    change_column_null :products, :name, false
    change_column_null :products, :slug, false
    change_column_null :products, :sku, false
    add_index :products, :slug, unique: true
    add_index :products, :sku, unique: true
  end
end
