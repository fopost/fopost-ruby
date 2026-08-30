# frozen_string_literal: true

require 'net/http'
require 'uri'
require 'fopost/http/response'
require 'fopost/http/transport'

module Fopost
  module HTTP
    # The default transport: Ruby's own net/http, so the gem needs no
    # dependency of its own.
    class NetHTTPTransport
      include Transport

      METHODS = {
        'GET' => Net::HTTP::Get,
        'POST' => Net::HTTP::Post,
        'PUT' => Net::HTTP::Put,
        'PATCH' => Net::HTTP::Patch,
        'DELETE' => Net::HTTP::Delete
      }.freeze

      def initialize(timeout: 30.0, open_timeout: nil)
        @timeout = timeout
        @open_timeout = open_timeout || timeout
      end

      def call(method:, url:, headers:, body:)
        uri = url.is_a?(URI) ? url : URI.parse(url)
        klass = METHODS.fetch(method.to_s.upcase) do
          raise ArgumentError, "fopost: unsupported HTTP method #{method}"
        end

        request = klass.new(uri)
        headers.each { |name, value| request[name] = value }
        request.body = body if body

        response = http_for(uri).request(request)
        Response.new(status: response.code.to_i, body: response.body || '',
                     headers: response.to_hash.transform_values(&:first))
      end

      private

      def http_for(uri)
        http = Net::HTTP.new(uri.host, uri.port)
        http.use_ssl = uri.scheme == 'https'
        http.read_timeout = @timeout
        http.write_timeout = @timeout if http.respond_to?(:write_timeout=)
        http.open_timeout = @open_timeout
        http
      end
    end
  end
end
