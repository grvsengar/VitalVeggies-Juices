class CreateNewsletterSignups < ActiveRecord::Migration[8.0]
  def change
    create_table :newsletter_signups do |t|
      t.string :email, null: false
      t.boolean :active, default: true, null: false

      t.timestamps
    end

    add_index :newsletter_signups, :email, unique: true
  end
end
