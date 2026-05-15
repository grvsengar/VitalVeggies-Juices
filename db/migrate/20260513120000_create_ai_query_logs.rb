class CreateAiQueryLogs < ActiveRecord::Migration[8.0]
  def change
    create_table :ai_query_logs do |t|
      t.references :user, foreign_key: true
      t.text :question, null: false
      t.text :sql
      t.string :status, null: false, default: "pending"
      t.string :llm_model
      t.integer :execution_duration_ms
      t.integer :row_count
      t.text :error_message
      t.timestamps
    end
  end
end
