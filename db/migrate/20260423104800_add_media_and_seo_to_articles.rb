class AddMediaAndSeoToArticles < ActiveRecord::Migration[8.0]
  def change
    add_column :articles, :image, :string
    add_column :articles, :video, :string
    add_column :articles, :meta_title, :string
    add_column :articles, :meta_description, :text
    add_column :articles, :social_caption, :text
  end
end
