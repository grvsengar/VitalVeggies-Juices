require "test_helper"

module LocalDbAi
  class OllamaClientTest < ActiveSupport::TestCase
    test "returns a helpful message when ollama is unavailable" do
      client = OllamaClient.new(base_url: "http://127.0.0.1:11434", model: "qwen2.5-coder:7b")
      error = Errno::ECONNREFUSED.new
      client.singleton_class.send(:define_method, :post_json) do |_path, _payload|
        raise error
      end

      raised = assert_raises(LocalDbAi::Error) do
        client.generate(system_prompt: "system", user_prompt: "question")
      end

      assert_match "Ollama is unavailable at http://127.0.0.1:11434", raised.message
      assert_match "ollama serve", raised.message
      assert_match "ollama pull qwen2.5-coder:7b", raised.message
    end
  end
end
