class CreateUsers < ActiveRecord::Migration[8.0]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :name
      t.integer :role, null: false, default: 2
      t.string :password_digest
      t.string :password_salt
      t.boolean :active, null: false, default: true
      t.string :invitation_token
      t.datetime :invitation_sent_at
      t.datetime :registered_at
      t.references :invited_by, foreign_key: { to_table: :users }
      t.timestamps
    end

    add_index :users, :email, unique: true
    add_index :users, :invitation_token, unique: true
  end
end
