# frozen_string_literal: true

module Fopost
  module Resources
    # `client.ai` — caption assist, per-platform rewriting, and blog fan-out.
    #
    # Every call spends AI credits. Check the balance with {#credits}; a
    # {Fopost::PaymentRequiredError} means the plan has none left.
    class Ai < Base
      # Credits remaining, used, and total for the current billing period.
      def credits
        AiCreditBalance.new(unwrap(http.get('/ai/credits')))
      end

      def generate_caption(current_caption: nil, image_urls: nil, platforms: nil,
                           char_limit: nil, workspace_id: nil, brand_voice_id: nil)
        body = compact_nil(
          'current_caption' => current_caption,
          'image_urls' => image_urls&.to_a,
          'platforms' => platforms&.to_a,
          'char_limit' => char_limit,
          'workspace_id' => workspace_id,
          'brand_voice_id' => brand_voice_id
        )
        CaptionResult.new(unwrap(http.post('/ai/generate-caption', body)))
      end

      # Rewrite one draft for each target platform. Costs 1 credit per platform.
      def rewrite(content:, platforms:, tone: nil, workspace_id: nil, brand_voice_id: nil)
        body = compact_nil(
          'content' => content,
          'platforms' => platforms.to_a,
          'tone' => tone,
          'workspace_id' => workspace_id,
          'brand_voice_id' => brand_voice_id
        )
        RewriteResult.new(unwrap(http.post('/ai/rewrite', body)))
      end

      # Turn an article URL into a post for each platform, in one call.
      def repurpose_url(url:, platforms:, workspace_id: nil, brand_voice_id: nil)
        body = compact_nil(
          'url' => url,
          'platforms' => platforms.to_a,
          'workspace_id' => workspace_id,
          'brand_voice_id' => brand_voice_id
        )
        RepurposeResult.new(unwrap(http.post('/ai/repurpose-url', body)))
      end
    end
  end
end
