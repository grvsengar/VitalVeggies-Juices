module LocalDbAi
  class Result
    attr_reader :code, :message, :payload

    def self.success(payload = {})
      new(success: true, payload:)
    end

    def self.failure(code:, message:, payload: {})
      new(success: false, code:, message:, payload:)
    end

    def initialize(success:, payload:, code: nil, message: nil)
      @success = success
      @payload = payload
      @code = code
      @message = message
    end

    def success?
      @success
    end

    def failure?
      !success?
    end

    def [](key)
      payload[key]
    end
  end
end
