# frozen_string_literal: true

module Fopost
  module Resources
    # `client.validate` — check a draft, its length, or a media URL against
    # platform rules before creating a post. Nothing is stored server-side.
    class Validate < Base
      # Full preflight: blockers per platform plus advisory signals.
      def post(platforms:, content: nil, media: nil)
        body = compact_nil(
          'content' => content,
          'media' => media&.map { |item| item.transform_keys(&:to_s) },
          'platforms' => platforms.to_a
        )
        ValidatePostResult.new(unwrap(http.post('/validate/post', body)))
      end

      # Text length against each platform's limit.
      def length(text:, platforms:)
        body = { 'text' => text, 'platforms' => platforms.to_a }
        ValidateLengthResult.new(unwrap(http.post('/validate/length', body)))
      end

      # Fetch a public URL and check the file. Answers 200 even when a check fails.
      def media(url:)
        ValidateMediaResult.new(unwrap(http.post('/validate/media', { 'url' => url })))
      end
    end
  end
end
