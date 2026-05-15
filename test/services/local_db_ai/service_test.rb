require "test_helper"

module LocalDbAi
  class ServiceTest < ActiveSupport::TestCase
    class FakeClient
      attr_reader :model

      def initialize(sql:, summary: "Revenue report", assumptions: [ "completed means delivered" ])
        @model = "test-local-model"
        @sql = sql
        @summary = summary
        @assumptions = assumptions
      end

      def generate(system_prompt:, user_prompt:)
        raise "missing system prompt" if system_prompt.blank?
        raise "missing user prompt" if user_prompt.blank?

        {
          sql: @sql,
          summary: @summary,
          assumptions: @assumptions
        }
      end
    end

    test "runs a natural language query through the service and logs it" do
      delivered_order = Order.create!(
        customer_name: "Service Test Customer",
        email: "service-test@example.com",
        phone: "9876543210",
        address_line1: "11 Test Lane",
        city: "Bengaluru",
        state: "Karnataka",
        postal_code: "560010",
        status: :delivered,
        subtotal: 125,
        discount_total: 0,
        delivery_fee: 0,
        total: 125,
        payment_method: "cash_on_delivery",
        payment_status: "paid"
      )

      service = Service.new(
        question: "Give me total revenue from completed orders",
        user: users(:manager),
        client: FakeClient.new(sql: "SELECT SUM(total) AS total_revenue FROM orders WHERE status = 4")
      )

      result = service.call

      assert result.success?, result.message
      assert_equal "Revenue report", result[:summary]
      assert_equal [ "completed means delivered" ], result[:assumptions]
      assert_equal 1, result[:row_count]
      assert_equal delivered_order.total.to_d, BigDecimal(result[:rows].first["total_revenue"].to_s)

      query_log = AiQueryLog.order(:created_at).last
      assert_equal "succeeded", query_log.status
      assert_equal users(:manager), query_log.user
      assert_match(/SELECT SUM\(total\)/, query_log.sql)
    end

    test "rejects very short prompts before calling ollama" do
      client = Object.new
      client.define_singleton_method(:model) { "unused-model" }
      client.define_singleton_method(:generate) { raise "should not be called" }

      result = Service.new(question: "hi", user: users(:manager), client: client).call

      assert result.failure?
      assert_equal "question_too_short", result.code
      assert_match "Ask a reporting question", result.message
    end
  end
end
