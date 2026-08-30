# frozen_string_literal: true

module Fopost
  module HTTP
    # What a {Transport} hands back: the raw status, headers, and body.
    class Response
      attr_reader :status, :headers, :body

      def initialize(status:, body: '', headers: {})
        @status = status
        @body = body.to_s
        @headers = headers.each_with_object({}) { |(k, v), out| out[k.to_s.downcase] = v }
      end

      def success?
        status >= 200 && status < 300
      end

      def header(name)
        headers[name.to_s.downcase]
      end
    end
  end
end
