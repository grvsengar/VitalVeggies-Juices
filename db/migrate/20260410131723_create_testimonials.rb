class CreateTestimonials < ActiveRecord::Migration[8.0]
  def change
    create_table :testimonials do |t|
      t.string :customer_name, null: false
      t.string :role
      t.text :quote, null: false
      t.integer :rating, null: false
      t.boolean :featured, default: false, null: false

      t.timestamps
    end
  end
end
