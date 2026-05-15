require "test_helper"

module LocalDbAi
  class HealthCheckTest < ActiveSupport::TestCase
    test "returns success when ollama endpoint responds with the configured model" do
      health_check = HealthCheck.new(base_url: "http://127.0.0.1:11434", model: "qwen2.5-coder:7b")
      response = Struct.new(:body, :code) do
        def is_a?(klass)
          klass == Net::HTTPSuccess || super
        end
      end.new({ models: [ { name: "qwen2.5-coder:7b" } ] }.to_json, "200")
      health_check.singleton_class.send(:define_method, :fetch_response) { response }

      result = health_check.call

      assert result.success?
      assert_equal true, result[:online]
      assert_equal true, result[:model_available]
    end

    test "returns failure when ollama is offline" do
      health_check = HealthCheck.new(base_url: "http://127.0.0.1:11434", model: "qwen2.5-coder:7b")
      health_check.singleton_class.send(:define_method, :fetch_response) { raise Errno::ECONNREFUSED }

      result = health_check.call

      assert result.failure?
      assert_equal "ollama_offline", result.code
      assert_match "Ollama is offline", result.message
    end
  end
end
