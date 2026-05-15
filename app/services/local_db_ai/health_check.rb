require "json"
require "net/http"
require "uri"

module LocalDbAi
  class HealthCheck
    def initialize(base_url: LocalDbAi.config.base_url, model: LocalDbAi.config.model)
      @base_url = base_url
      @model = model
    end

    def call
      response = fetch_response

      return offline("Ollama returned HTTP #{response.code}.") unless response.is_a?(Net::HTTPSuccess)

      payload = JSON.parse(response.body)
      models = Array(payload["models"])
      model_names = models.map { |entry| entry["name"].to_s }

      LocalDbAi::Result.success(
        online: true,
        base_url:,
        model:,
        model_available: model_names.include?(model),
        available_models: model_names
      )
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError => e
      offline("Ollama is offline at #{base_url}. Start it with `ollama serve`. Original error: #{e.message}")
    rescue JSON::ParserError => e
      offline("Ollama returned invalid JSON from #{base_url}/api/tags: #{e.message}")
    rescue StandardError => e
      offline("Unable to check Ollama health at #{base_url}: #{e.message}")
    end

    private

    attr_reader :base_url, :model

    def fetch_response
      uri = URI.join(base_url, "/api/tags")
      request = Net::HTTP::Get.new(uri)

      Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: 2,
        read_timeout: 5
      ) do |http|
        http.request(request)
      end
    end

    def offline(message)
      LocalDbAi::Result.failure(
        code: "ollama_offline",
        message:,
        payload: {
          online: false,
          base_url:,
          model:
        }
      )
    end
  end
end
