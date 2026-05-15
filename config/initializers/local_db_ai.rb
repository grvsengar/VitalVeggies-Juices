Rails.application.config.x.local_db_ai = ActiveSupport::OrderedOptions.new.tap do |config|
  config.enabled               = ENV.fetch("LOCAL_DB_AI_ENABLED", "true") == "true"
  config.base_url              = ENV.fetch("OLLAMA_URL", "http://127.0.0.1:11434")
  config.model                 = ENV.fetch("OLLAMA_MODEL", "qwen2.5-coder:7b")
  config.statement_timeout_ms  = ENV.fetch("LOCAL_DB_AI_STATEMENT_TIMEOUT_MS", "5000").to_i
  config.default_limit         = ENV.fetch("LOCAL_DB_AI_DEFAULT_LIMIT", "200").to_i
  # Ollama generation options — keep tight for speed
  config.num_ctx               = ENV.fetch("OLLAMA_NUM_CTX", "600").to_i
  config.num_predict           = ENV.fetch("OLLAMA_NUM_PREDICT", "200").to_i
end

# Warm up Ollama model in background on boot so first request isn't slow
Rails.application.config.after_initialize do
  if Rails.env.development? || Rails.env.production?
    Thread.new do
      sleep 3 # wait for server to fully boot
      begin
        require "net/http"
        require "json"
        uri = URI("#{Rails.application.config.x.local_db_ai.base_url}/api/generate")
        req = Net::HTTP::Post.new(uri, "Content-Type" => "application/json")
        req.body = JSON.generate({
          model:      Rails.application.config.x.local_db_ai.model,
          prompt:     "hi",
          stream:     false,
          keep_alive: "30m",
          options:    { num_predict: 1 }
        })
        Net::HTTP.start(uri.host, uri.port, open_timeout: 5, read_timeout: 120) { |h| h.request(req) }
        Rails.logger.info("[LocalDbAi] model warmed up and kept alive for 30 min")
      rescue StandardError => e
        Rails.logger.warn("[LocalDbAi] warm-up failed (Ollama may not be running): #{e.message}")
      end
    end
  end
end
