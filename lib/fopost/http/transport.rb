# frozen_string_literal: true

module Fopost
  module HTTP
    # The seam the SDK sends requests through.
    #
    # Implement `call` and pass an instance as `transport:` to swap in your own
    # HTTP stack, or to stub the network in tests.
    #
    #   class MyTransport
    #     def call(method:, url:, headers:, body:)
    #       Fopost::HTTP::Response.new(status: 200, body: '{}')
    #     end
    #   end
    module Transport
      def call(method:, url:, headers:, body:)
        raise NotImplementedError, 'a transport must implement #call'
      end
    end
  end
end
