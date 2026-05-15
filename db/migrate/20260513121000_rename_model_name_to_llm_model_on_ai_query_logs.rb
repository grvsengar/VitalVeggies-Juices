class RenameModelNameToLlmModelOnAiQueryLogs < ActiveRecord::Migration[8.0]
  def up
    return unless column_exists?(:ai_query_logs, :model_name)

    rename_column :ai_query_logs, :model_name, :llm_model
  end

  def down
    return unless column_exists?(:ai_query_logs, :llm_model)

    rename_column :ai_query_logs, :llm_model, :model_name
  end
end
