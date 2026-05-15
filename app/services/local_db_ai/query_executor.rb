module LocalDbAi
  class QueryExecutor
    def initialize(connection: ActiveRecord::Base.connection, validator: SqlValidator.new)
      @connection = connection
      @validator = validator
    end

    def call(sql)
      validation = validator.validate(sql)
      return validation if validation.failure?

      safe_sql = apply_limit(validation[:sql])
      result = nil

      connection.transaction do
        connection.execute("SET LOCAL statement_timeout = '#{LocalDbAi.config.statement_timeout_ms}ms'")
        connection.execute("SET LOCAL transaction_read_only = on")
        result = connection.exec_query(safe_sql)
        raise ActiveRecord::Rollback
      end

      rows = result.to_a
      Result.success(
        sql: safe_sql,
        columns: result.columns,
        rows:,
        row_count: rows.length
      )
    rescue ActiveRecord::StatementInvalid => e
      Result.failure(code: "execution_error", message: e.message)
    end

    private

    attr_reader :connection, :validator

    def apply_limit(sql)
      stripped_sql = sql.to_s.strip.delete_suffix(";")
      return stripped_sql if stripped_sql.match?(/\blimit\s+\d+\b/i)

      "#{stripped_sql} LIMIT #{LocalDbAi.config.default_limit}"
    end
  end
end
