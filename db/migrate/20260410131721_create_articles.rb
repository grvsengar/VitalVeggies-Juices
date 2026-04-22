class CreateArticles < ActiveRecord::Migration[8.0]
  def change
    create_table :articles do |t|
      t.string :title, null: false
      t.string :slug, null: false
      t.text :excerpt, null: false
      t.text :body, null: false
      t.boolean :published, default: true, null: false
      t.date :published_on
      t.boolean :featured, default: false, null: false

      t.timestamps
    end

    add_index :articles, :slug, unique: true
  end
end
