require "json"
require "net/http"
require "uri"

module LocalDbAi
  class OllamaClient
    def initialize(base_url: LocalDbAi.config.base_url, model: LocalDbAi.config.model)
      @base_url = base_url
      @model = model
    end

    attr_reader :model

    def generate(system_prompt:, user_prompt:)
      response = post_json(
        "/api/generate",
        {
          model:,
          system: system_prompt,
          prompt:      user_prompt,
          format:      "json",
          stream:      false,
          keep_alive:  "30m",
          options: {
            temperature: 0,
            num_ctx:     LocalDbAi.config.num_ctx,
            num_predict: LocalDbAi.config.num_predict
          }
        }
      )

      parse_response_payload(response)
    rescue Errno::ECONNREFUSED, Errno::EHOSTUNREACH, SocketError => e
      raise Error, unavailable_message(e)
    rescue JSON::ParserError => e
      raise Error, "Ollama returned invalid JSON: #{e.message}"
    rescue StandardError => e
      raise Error, "Ollama request failed: #{e.message}"
    end

    private

    attr_reader :base_url

    def post_json(path, payload)
      uri = URI.join(base_url, path)
      request = Net::HTTP::Post.new(uri)
      request["Content-Type"] = "application/json"
      request.body = JSON.generate(payload)

      response = Net::HTTP.start(
        uri.host,
        uri.port,
        use_ssl: uri.scheme == "https",
        open_timeout: 10,
        read_timeout: 180
      ) do |http|
        http.request(request)
      end

      parsed_body = JSON.parse(response.body)
      return parsed_body if response.is_a?(Net::HTTPSuccess)

      raise Error, parsed_body["error"].presence || "HTTP #{response.code}"
    end

    def parse_response_payload(response)
      raw_payload = response["response"].presence || response.dig("message", "content").to_s
      parsed = JSON.parse(raw_payload)

      {
        sql: extract_sql(parsed["sql"]),
        summary: parsed["summary"].to_s.strip,
        assumptions: Array(parsed["assumptions"]).map(&:to_s),
        raw_response: raw_payload
      }
    rescue JSON::ParserError
      {
        sql: extract_sql(raw_payload),
        summary: "",
        assumptions: [],
        raw_response: raw_payload
      }
    end

    def extract_sql(value)
      text = value.to_s.strip
      fenced = text.match(/\A```(?:sql)?\s*(.*?)\s*```\z/m)
      sql = fenced ? fenced[1] : text
      sql.strip
    end

    def unavailable_message(error)
      "Ollama is unavailable at #{base_url}. Start the local server with `ollama serve`, then pull or confirm the model with `ollama pull #{model}`. Original error: #{error.message}"
    end
  end
end
