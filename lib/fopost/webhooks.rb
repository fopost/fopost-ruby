# frozen_string_literal: true

require 'json'
require 'openssl'
require 'time'

require 'fopost/models'

module Fopost
  # Raised when a webhook delivery cannot be trusted.
  class WebhookSignatureError < StandardError; end

  # Verifies the signature FoPost puts on every outbound webhook, including
  # the website target of the blog.
  #
  #   event = Fopost::Webhooks.verify(request.raw_post, request.headers, secret)
  #   event.article.title if event.event == 'article.published'
  #
  # Verify the raw request bytes, never re-serialised JSON: key order and
  # whitespace change the bytes and the signature no longer matches.
  module Webhooks
    SIGNATURE_HEADER = 'x-fopost-signature'
    TIMESTAMPED_SIGNATURE_HEADER = 'x-fopost-signature-256'
    TIMESTAMP_HEADER = 'x-fopost-timestamp'
    EVENT_HEADER = 'x-fopost-event'
    DELIVERY_HEADER = 'x-fopost-delivery'
    DEFAULT_TOLERANCE = 300

    module_function

    # Returns the parsed envelope as a {Fopost::WebhookEvent}, or raises
    # {Fopost::WebhookSignatureError}.
    #
    # The timestamped signature is checked when `X-FoPost-Timestamp` is
    # present and rejected when it is older than `tolerance` seconds; the
    # plain body signature is accepted only when no timestamp was sent.
    # `headers` may use any casing; a Rack `HTTP_X_FOPOST_*` key also works.
    def verify(raw_body, headers, secret, tolerance: DEFAULT_TOLERANCE, now: nil)
      raise WebhookSignatureError, 'fopost: a webhook secret is required' if secret.nil? || secret.to_s.empty?

      body = raw_body.to_s
      lookup = normalize_headers(headers)
      timestamp = lookup[TIMESTAMP_HEADER]

      if timestamp
        check_timestamp(timestamp, tolerance, now)
        expected = sign("#{timestamp}.#{body}", secret)
        match = secure_equal(lookup[TIMESTAMPED_SIGNATURE_HEADER], expected)
      else
        match = secure_equal(lookup[SIGNATURE_HEADER], sign(body, secret))
      end
      raise WebhookSignatureError, 'fopost: webhook signature mismatch' unless match

      parse(body)
    end

    # The header value FoPost sends for these exact bytes.
    def sign(payload, secret)
      "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', secret.to_s, payload)}"
    end

    def check_timestamp(timestamp, tolerance, now)
      seconds = Integer(timestamp.to_s.strip, exception: false)
      raise WebhookSignatureError, 'fopost: webhook timestamp is not a number' unless seconds

      drift = ((now || Time.now).to_i - seconds).abs
      raise WebhookSignatureError, 'fopost: webhook timestamp outside tolerance' if drift > tolerance
    end

    def secure_equal(given, expected)
      return false if given.nil?

      given = given.to_s.strip
      return false unless given.bytesize == expected.bytesize

      OpenSSL.fixed_length_secure_compare(given, expected)
    end

    def parse(body)
      data = JSON.parse(body)
      raise WebhookSignatureError, 'fopost: webhook body is not an object' unless data.is_a?(Hash)

      WebhookEvent.new(data)
    rescue JSON::ParserError
      raise WebhookSignatureError, 'fopost: webhook body is not JSON'
    end

    def normalize_headers(headers)
      (headers || {}).each_with_object({}) do |(key, value), out|
        name = key.to_s.downcase.tr('_', '-').sub(/\Ahttp-/, '')
        out[name] = value.is_a?(Array) ? value.first : value
      end
    end

    private_class_method :check_timestamp, :secure_equal, :parse, :normalize_headers
  end
end
