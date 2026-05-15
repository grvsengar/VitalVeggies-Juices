require "test_helper"

class PortalAiQueriesTest < ActionDispatch::IntegrationTest
  setup do
    @original_service_class = Portal::AiQueriesController.local_db_ai_service_class
    @original_health_check_class = Portal::AiQueriesController.local_db_ai_health_check_class
  end

  teardown do
    Portal::AiQueriesController.local_db_ai_service_class = @original_service_class
    Portal::AiQueriesController.local_db_ai_health_check_class = @original_health_check_class
  end

  test "redirects guests to login" do
    get portal_ai_query_path

    assert_redirected_to login_path
  end

  test "manager can open the console and run a query" do
    post login_path, params: { email: users(:manager).email, password: "password123" }
    follow_redirect!

    Portal::AiQueriesController.local_db_ai_health_check_class = Class.new do
      def call
        LocalDbAi::Result.success(
          online: true,
          base_url: "http://127.0.0.1:11434",
          model: "qwen2.5-coder:7b",
          model_available: true,
          available_models: [ "qwen2.5-coder:7b" ]
        )
      end
    end

    get portal_ai_query_path
    assert_response :success
    assert_match "AI query console", response.body
    assert_match "Ollama status:", response.body
    assert_match "Online at", response.body

    fake_service_class = Class.new do
      define_method(:initialize) do |question:, user:|
        @question = question
        @user = user
      end

      define_method(:call) do
        LocalDbAi::Result.success(
          sql: "SELECT COUNT(*) AS orders_count FROM orders LIMIT 200",
          summary: "Orders counted successfully.",
          assumptions: [],
          columns: [ "orders_count" ],
          rows: [ { "orders_count" => 2 } ],
          row_count: 1
        )
      end
    end

    Portal::AiQueriesController.local_db_ai_service_class = fake_service_class
    post portal_ai_query_path, params: { ai_query: { question: "How many orders do we have?" } }
    assert_response :success
    assert_match "Orders counted successfully.", response.body
    assert_match "SELECT COUNT(*) AS orders_count FROM orders LIMIT 200", response.body
  end

  test "buyer cannot access the console" do
    post login_path, params: { email: users(:buyer).email, password: "password123" }
    follow_redirect!

    get portal_ai_query_path

    assert_redirected_to login_path
  end

  test "offline health status is shown on the page" do
    post login_path, params: { email: users(:manager).email, password: "password123" }
    follow_redirect!

    Portal::AiQueriesController.local_db_ai_health_check_class = Class.new do
      def call
        LocalDbAi::Result.failure(
          code: "ollama_offline",
          message: "Ollama is offline at http://127.0.0.1:11434.",
          payload: { online: false, base_url: "http://127.0.0.1:11434", model: "qwen2.5-coder:7b" }
        )
      end
    end

    get portal_ai_query_path

    assert_response :success
    assert_match "Ollama is offline at http://127.0.0.1:11434.", response.body
  end
end
