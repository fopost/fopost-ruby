# frozen_string_literal: true

require 'time'
require 'fopost/unset'

module Fopost
  module Resources
    class Base
      def initialize(http)
        @http = http
      end

      private

      attr_reader :http

      def unwrap(body)
        Fopost::HTTP::Client.unwrap(body)
      end

      def parse_list(model, data)
        data.is_a?(Array) ? data.map { |item| model.new(item) } : []
      end

      def as_hash(body)
        body.is_a?(Hash) ? body : { 'data' => body }
      end

      # Strip the keys the caller never passed, so a PUT stays a partial update.
      def compact_unset(body)
        body.reject { |_, value| UNSET.equal?(value) }
      end

      def compact_nil(body)
        body.compact
      end

      def iso8601(value)
        case value
        when nil then nil
        when String then value
        when Time then value.utc.strftime('%Y-%m-%dT%H:%M:%SZ')
        else
          value.respond_to?(:iso8601) ? value.iso8601 : value.to_s
        end
      end
    end
  end
end
