module LocalDbAi
  class SqlValidator
    TABLE_REFERENCE_REGEX = /\b(?:from|join)\s+("?[\w\.]+"?)/i
    CTE_NAME_REGEX = /(?:\bwith\b|,)\s*("?[\w]+"?)\s+as\s*\(/i

    def validate(sql)
      normalized_sql = normalize_sql(sql)
      return failure("blank_sql", "The AI did not return any SQL.") if normalized_sql.blank?
      return failure("multiple_statements", "Only a single SQL statement is allowed.") unless single_statement?(normalized_sql)
      return failure("invalid_root", "Only SELECT or WITH queries are allowed.") unless normalized_sql.match?(/\A(?:select|with)\b/i)
      return failure("forbidden_keyword", "The generated SQL contains a forbidden keyword.") if forbidden_keyword?(normalized_sql)
      return failure("forbidden_function", "The generated SQL contains a forbidden function.") if forbidden_function?(normalized_sql)
      return failure("restricted_column", "The generated SQL references restricted columns.") if restricted_column?(normalized_sql)

      disallowed_tables = referenced_tables(normalized_sql) - allowed_reference_names(normalized_sql)
      return failure("disallowed_table", "The generated SQL references tables outside the allowlist: #{disallowed_tables.join(', ')}.") if disallowed_tables.any?

      Result.success(sql: normalized_sql.delete_suffix(";"))
    end

    private

    def failure(code, message)
      Result.failure(code:, message:)
    end

    def normalize_sql(sql)
      sql.to_s.strip
    end

    def single_statement?(sql)
      scrubbed = strip_comments_and_strings(sql)
      semicolons = scrubbed.count(";")
      return true if semicolons.zero?
      return false if semicolons > 1

      scrubbed.rstrip.end_with?(";")
    end

    def forbidden_keyword?(sql)
      scrubbed = strip_comments_and_strings(sql)
      LocalDbAi::DISALLOWED_KEYWORDS.any? do |keyword|
        scrubbed.match?(/\b#{Regexp.escape(keyword)}\b/i)
      end
    end

    def forbidden_function?(sql)
      scrubbed = strip_comments_and_strings(sql)
      LocalDbAi::DISALLOWED_FUNCTIONS.any? do |function_name|
        scrubbed.match?(/\b#{Regexp.escape(function_name)}\s*\(/i)
      end
    end

    def restricted_column?(sql)
      scrubbed = strip_comments_and_strings(sql)
      LocalDbAi::RESTRICTED_COLUMNS.any? do |column_name|
        scrubbed.match?(/\b#{Regexp.escape(column_name)}\b/i)
      end
    end

    def referenced_tables(sql)
      strip_comments_and_strings(sql).scan(TABLE_REFERENCE_REGEX).flatten.map do |identifier|
        identifier.delete('"').split(".").last
      end.uniq
    end

    def allowed_reference_names(sql)
      LocalDbAi::ALLOWED_TABLES + cte_names(sql)
    end

    def cte_names(sql)
      strip_comments_and_strings(sql).scan(CTE_NAME_REGEX).flatten.map { |name| name.delete('"') }.uniq
    end

    def strip_comments_and_strings(sql)
      sql
        .gsub(/--.*$/, "")
        .gsub(%r{/\*.*?\*/}m, "")
        .gsub(/'(?:''|[^'])*'/, "''")
    end
  end
end
