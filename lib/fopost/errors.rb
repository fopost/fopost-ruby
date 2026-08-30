# frozen_string_literal: true

module Fopost
  # Base class for every error the FoPost API returns.
  #
  # The API answers failures with an `{"error": "<code>", "message": "<human
  # readable>"}` envelope, which maps onto {#code} and {#message}.
  class Error < StandardError
    attr_reader :status, :code, :body

    # The message the API sent, undecorated. `to_s` adds the status and code,
    # so an uncaught error still reports both.
    attr_reader :message

    def initialize(message, status:, code: nil, body: nil)
      super(message)
      @message = message
      @status = status
      @code = code
      @body = body
    end

    def to_s
      suffix = code ? " (#{code})" : ''
      "[#{status}#{suffix}] #{@message}"
    end
  end

  # Raised before a request goes out, when the client is misconfigured.
  class ConfigurationError < StandardError; end

  # 400 or 422 — the request body did not pass validation.
  class ValidationError < Error
    # Per-field messages, when the API sends them.
    def errors
      value = body.is_a?(Hash) ? (body['errors'] || body[:errors]) : nil
      value.is_a?(Hash) || value.is_a?(Array) ? value : nil
    end
  end

  # 401 — missing, invalid, or expired API key.
  class AuthenticationError < Error; end

  # 402 — no active subscription, or AI credits exhausted.
  class PaymentRequiredError < Error
    # The page the API suggests sending the user to.
    def upgrade_url
      value = body.is_a?(Hash) ? (body['upgrade_url'] || body[:upgrade_url]) : nil
      value.is_a?(String) ? value : nil
    end
  end

  # 403 — the key is valid but lacks the scope or the workspace.
  class PermissionDeniedError < Error; end

  # 404 — no such resource, or it is outside the key's reach.
  class NotFoundError < Error; end

  # 429 — rate limit exceeded. {#retry_after} is in seconds when the API sends it.
  class RateLimitError < Error
    attr_reader :retry_after

    def initialize(message, status:, code: nil, body: nil, retry_after: nil)
      super(message, status: status, code: code, body: body)
      @retry_after = retry_after
    end
  end

  # Maps an HTTP status plus a decoded body onto the most specific error class.
  module ErrorFactory
    BY_STATUS = {
      400 => ValidationError,
      401 => AuthenticationError,
      402 => PaymentRequiredError,
      403 => PermissionDeniedError,
      404 => NotFoundError,
      422 => ValidationError,
      429 => RateLimitError
    }.freeze

    def self.build(status, body, retry_after: nil)
      code = nil
      message = "HTTP #{status}"

      if body.is_a?(Hash)
        code = body['error'] if body['error'].is_a?(String)
        if body['message'].is_a?(String) && !body['message'].empty?
          message = body['message']
        elsif code
          message = code
        end
      elsif body.is_a?(String) && !body.strip.empty?
        message = body.strip
      end

      klass = BY_STATUS.fetch(status, Error)
      if klass == RateLimitError
        return RateLimitError.new(message, status: status, code: code, body: body,
                                           retry_after: retry_after)
      end

      klass.new(message, status: status, code: code, body: body)
    end
  end
end
