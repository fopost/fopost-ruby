# frozen_string_literal: true

module Fopost
  module Resources
    # `client.knowledge` — what the workspace has told FoPost about itself.
    #
    # A source is an FAQ, a note, a page on your own site, or a plain-text/CSV
    # item from the media library. Retrieval over these is what grounds a
    # drafted inbox reply in your own answers instead of an invented one.
    # Needs the `inbox` scope.
    class Knowledge < Base
      def list(workspace_id: nil)
        parse_list(
          KnowledgeSource,
          unwrap(http.get('/knowledge/sources', { 'workspace_id' => workspace_id }))
        )
      end

      # Adds a source and queues it for indexing, so it comes back `pending`.
      #
      # `kind` is `faq`, `text`, `url` or `file`. An `faq` or `text` source
      # needs `content`, a `url` source needs `url`, and a `file` source needs
      # `media_id` pointing at a plain-text or CSV item in the same workspace.
      def create(kind:, title:, content: nil, url: nil, media_id: nil, brand_voice_id: nil,
                 workspace_id: nil)
        body = compact_nil(
          'kind' => kind,
          'title' => title,
          'content' => content,
          'url' => url,
          'media_id' => media_id,
          'brand_voice_id' => brand_voice_id,
          'workspace_id' => workspace_id
        )
        KnowledgeSource.new(unwrap(http.post('/knowledge/sources', body)))
      end

      # Partial update. Changing the content or the URL returns the source to
      # `pending` and re-indexes it.
      def update(source_id, title: UNSET, content: UNSET, url: UNSET, brand_voice_id: UNSET)
        body = compact_unset(
          'title' => title,
          'content' => content,
          'url' => url,
          'brand_voice_id' => brand_voice_id
        )
        KnowledgeSource.new(unwrap(http.patch("/knowledge/sources/#{source_id}", body)))
      end

      # Removes the source and every passage indexed from it.
      def delete(source_id)
        http.delete("/knowledge/sources/#{source_id}")
        nil
      end

      # Reads the source again — a `url` source is re-fetched. Returns once queued.
      def sync(source_id)
        http.post("/knowledge/sources/#{source_id}/sync", {})
        nil
      end

      # The passages closest to a question, best first. Empty is the honest
      # answer when nothing stored answers it.
      def search(q, top_k: nil, brand_voice_id: nil, workspace_id: nil)
        parse_list(KnowledgeMatch, unwrap(http.get('/knowledge/search', {
                                                     'q' => q,
                                                     'top_k' => top_k,
                                                     'brand_voice_id' => brand_voice_id,
                                                     'workspace_id' => workspace_id
                                                   })))
      end
    end
  end
end
