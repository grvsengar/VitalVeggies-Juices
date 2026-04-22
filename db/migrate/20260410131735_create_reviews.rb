class CreateReviews < ActiveRecord::Migration[8.0]
  def change
    create_table :reviews do |t|
      t.references :product, null: false, foreign_key: true
      t.string :customer_name, null: false
      t.string :title, null: false
      t.text :body, null: false
      t.integer :rating, null: false
      t.boolean :approved, default: false, null: false

      t.timestamps
    end
  end
end
