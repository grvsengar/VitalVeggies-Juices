require "base64"
require "json"
require "net/http"
require "openssl"

class RazorpayClient
  class Error < StandardError; end

  BASE_URL = "https://api.razorpay.com/v1".freeze

  def self.configured?
    ENV["RAZORPAY_KEY_ID"].present? && ENV["RAZORPAY_KEY_SECRET"].present?
  end

  def initialize(key_id: ENV["RAZORPAY_KEY_ID"], key_secret: ENV["RAZORPAY_KEY_SECRET"])
    @key_id = key_id
    @key_secret = key_secret
    raise Error, "Razorpay credentials are missing." if @key_id.blank? || @key_secret.blank?
  end

  attr_reader :key_id

  def create_order(amount:, receipt:, notes: {})
    request(
      Net::HTTP::Post,
      "/orders",
      {
        amount:,
        currency: "INR",
        receipt:,
        notes:
      }
    )
  end

  def fetch_payment(payment_id)
    request(Net::HTTP::Get, "/payments/#{payment_id}")
  end

  def capture_payment(payment_id, amount:, currency: "INR")
    request(
      Net::HTTP::Post,
      "/payments/#{payment_id}/capture",
      {
        amount:,
        currency:
      }
    )
  end

  def valid_signature?(order_id:, payment_id:, signature:)
    return false if order_id.blank? || payment_id.blank? || signature.blank?

    payload = "#{order_id}|#{payment_id}"
    expected_signature = self.class.hmac_signature(secret: @key_secret, payload:)
    ActiveSupport::SecurityUtils.secure_compare(expected_signature, signature)
  end

  def self.valid_webhook_signature?(payload:, signature:, secret: ENV["RAZORPAY_WEBHOOK_SECRET"])
    return false if payload.blank? || signature.blank? || secret.blank?

    expected_signature = hmac_signature(secret:, payload:)
    ActiveSupport::SecurityUtils.secure_compare(expected_signature, signature)
  end

  private

  def self.hmac_signature(secret:, payload:)
    OpenSSL::HMAC.hexdigest("SHA256", secret, payload)
  end

  def request(http_method, path, payload = nil)
    uri = URI("#{BASE_URL}#{path}")
    request = http_method.new(uri)
    request["Authorization"] = "Basic #{Base64.strict_encode64("#{@key_id}:#{@key_secret}")}"
    request["Content-Type"] = "application/json"
    request.body = JSON.generate(payload) if payload.present?

    response = Net::HTTP.start(
      uri.hostname,
      uri.port,
      use_ssl: uri.scheme == "https",
      open_timeout: 10,
      read_timeout: 20
    ) do |http|
      http.request(request)
    end

    parsed_response = response.body.present? ? JSON.parse(response.body) : {}
    return parsed_response if response.is_a?(Net::HTTPSuccess)

    message = parsed_response.dig("error", "description") || parsed_response.dig("error", "message") || "Razorpay request failed."
    raise Error, message
  rescue JSON::ParserError
    raise Error, "Razorpay returned an unreadable response."
  rescue Net::OpenTimeout, Net::ReadTimeout
    raise Error, "Razorpay timed out. Please try again."
  end
end
