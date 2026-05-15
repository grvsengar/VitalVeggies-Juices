module LocalDbAi
  # Caches successful query results for 5 minutes keyed by normalized question.
  # Same question = instant response, no Ollama call.
  class QueryCache
    TTL = 5.minutes

    def self.fetch(question, &block)
      key = cache_key(question)
      cached = Rails.cache.read(key)
      if cached
        Rails.logger.info("[LocalDbAi] cache HIT key=#{key}")
        return Result.success(cached.merge(from_cache: true))
      end

      result = block.call
      if result.success? && !result[:conversational]
        Rails.logger.info("[LocalDbAi] cache SET key=#{key}")
        Rails.cache.write(key, result.payload, expires_in: TTL)
      end
      result
    end

    def self.invalidate!(question)
      Rails.cache.delete(cache_key(question))
    end

    def self.cache_key(question)
      normalized = question.to_s.downcase.gsub(/\s+/, " ").strip
      "local_db_ai:v1:#{Digest::MD5.hexdigest(normalized)}"
    end
  end
end
