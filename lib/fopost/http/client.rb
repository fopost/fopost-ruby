# frozen_string_literal: true

require 'json'
require 'time'
require 'uri'

require 'fopost/errors'
require 'fopost/version'
require 'fopost/http/net_http_transport'

module Fopost
  module HTTP
    # Internal transport wrapper: auth headers, JSON coding, envelope unwrap,
    # and the 429 retry. One per {Fopost::Client}.
    class Client
      DEFAULT_BASE_URL = 'https://api.fopost.com/v1'
      DEFAULT_TIMEOUT = 30.0
      DEFAULT_MAX_RETRIES = 3
      MAX_RETRY_WAIT = 60.0

      USER_AGENT = "fopost-ruby/#{Fopost::VERSION}".freeze

      attr_reader :base_url, :max_retries

      def initialize(api_key:, base_url: DEFAULT_BASE_URL, timeout: DEFAULT_TIMEOUT,
                     max_retries: DEFAULT_MAX_RETRIES, transport: nil, sleeper: nil)
        raise ConfigurationError, 'fopost: api_key is required' if api_key.nil? || api_key.to_s.empty?
        raise ConfigurationError, 'fopost: max_retries must be at least 1' if max_retries < 1

        @api_key = api_key
        @base_url = base_url.to_s.sub(%r{/+\z}, '')
        @max_retries = max_retries
        @transport = transport || NetHTTPTransport.new(timeout: timeout)
        # Indirected so tests can replace the wait without touching the real clock.
        @sleeper = sleeper || ->(seconds) { sleep(seconds) }
      end

      def headers
        {
          'Accept' => 'application/json',
          'Content-Type' => 'application/json',
          'X-API-Key' => @api_key,
          'User-Agent' => USER_AGENT
        }
      end

      # Send a request, retrying on 429, and return the decoded body.
      def request(method, path, json: nil, params: nil)
        url = build_url(path, params)
        body = json.nil? ? nil : JSON.generate(json)

        attempt = 0
        loop do
          attempt += 1
          response = @transport.call(method: method.to_s.upcase, url: url, headers: headers, body: body)

          if response.status == 429 && attempt < @max_retries
            wait = retry_after_seconds(response)
            @sleeper.call([wait || 1.0, MAX_RETRY_WAIT].min)
            next
          end

          return decode(response)
        end
      end

      def get(path, params = nil)
        request(:get, path, params: params)
      end

      def post(path, json = nil)
        request(:post, path, json: json)
      end

      def put(path, json = nil)
        request(:put, path, json: json)
      end

      def delete(path, json = nil)
        request(:delete, path, json: json)
      end

      # Peel the `{"data": ...}` envelope the API wraps most responses in. Some
      # endpoints (POST /posts, GET /posts/:id) return the resource bare, so the
      # envelope comes off only when it is actually there.
      def self.unwrap(body)
        body.is_a?(Hash) && body.key?('data') ? body['data'] : body
      end

      private

      def build_url(path, params)
        uri = URI.parse(path.to_s)
        uri = URI.parse("#{@base_url}/#{path.to_s.sub(%r{\A/+}, '')}") if uri.scheme.nil?

        query = (params || {}).compact
        unless query.empty?
          existing = uri.query.to_s
          encoded = URI.encode_www_form(query.map { |k, v| [k.to_s, v.to_s] })
          uri.query = existing.empty? ? encoded : "#{existing}&#{encoded}"
        end
        uri
      end

      def decode(response)
        body = decode_body(response)

        if response.success?
          if body.is_a?(String)
            content_type = response.header('content-type')
            raise Error.new(
              "Expected a JSON response, got #{content_type || 'no content type'}",
              status: response.status,
              body: body
            )
          end
          return body
        end

        raise ErrorFactory.build(response.status, body, retry_after: retry_after_seconds(response))
      end

      def decode_body(response)
        return nil if response.status == 204 || response.body.nil? || response.body.empty?

        JSON.parse(response.body)
      rescue JSON::ParserError
        response.body
      end

      # Retry-After is either delta-seconds or an HTTP date.
      def retry_after_seconds(response)
        raw = response.header('retry-after')
        return nil if raw.nil?

        raw = raw.to_s.strip
        return nil if raw.empty?

        seconds = Float(raw, exception: false)
        return [0.0, seconds].max if seconds

        target = Time.httpdate(raw) rescue (Time.parse(raw) rescue nil)
        return nil unless target

        [0.0, target.to_f - Time.now.to_f].max
      end
    end
  end
end
