require "test_helper"

module LocalDbAi
  class SqlValidatorTest < ActiveSupport::TestCase
    setup do
      @validator = SqlValidator.new
    end

    test "accepts a select query on allowlisted tables" do
      result = @validator.validate("SELECT orders.order_number, orders.total FROM orders ORDER BY orders.created_at DESC")

      assert result.success?
      assert_equal "SELECT orders.order_number, orders.total FROM orders ORDER BY orders.created_at DESC", result[:sql]
    end

    test "rejects restricted columns" do
      result = @validator.validate("SELECT email, password_digest FROM users")

      assert result.failure?
      assert_equal "restricted_column", result.code
    end

    test "rejects disallowed tables" do
      result = @validator.validate("SELECT * FROM ar_internal_metadata")

      assert result.failure?
      assert_equal "disallowed_table", result.code
    end

    test "rejects multiple statements" do
      result = @validator.validate("SELECT * FROM orders; DELETE FROM orders")

      assert result.failure?
      assert_equal "multiple_statements", result.code
    end
  end
end
