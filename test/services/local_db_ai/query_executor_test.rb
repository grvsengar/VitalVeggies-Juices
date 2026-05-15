require "test_helper"

module LocalDbAi
  class QueryExecutorTest < ActiveSupport::TestCase
    test "executes validated read only sql with a fallback limit" do
      result = QueryExecutor.new.call("SELECT order_number, total FROM orders ORDER BY order_number")

      assert result.success?, result.message
      assert_equal [ "order_number", "total" ], result[:columns]
      assert_equal 2, result[:row_count]
      assert_match(/LIMIT #{LocalDbAi.config.default_limit}\z/i, result[:sql])
    end

    test "returns a structured failure for invalid sql" do
      result = QueryExecutor.new.call("SELECT missing_column FROM orders")

      assert result.failure?
      assert_equal "execution_error", result.code
    end
  end
end
