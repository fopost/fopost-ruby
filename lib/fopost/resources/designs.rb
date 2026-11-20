# frozen_string_literal: true

module Fopost
  module Resources
    # `client.designs` — designs made in the editor: stories, posts, carousels,
    # thumbnails, cards and collages. Needs the `posts` scope; `text_to_slides`
    # also needs `ai`. The document is a plain Hash, sent and returned as is.
    class Designs < Base
      # Newest first, without the document. `kind` narrows to one design kind.
      def list(workspace_id:, kind: nil, limit: nil, offset: nil)
        query = compact_nil('workspace_id' => workspace_id, 'kind' => kind, 'limit' => limit, 'offset' => offset)
        parse_list(Design, unwrap(http.get('/designs', query)))
      end

      # `document` defaults to a blank page sized for `kind`.
      def create(workspace_id:, kind:, name: nil, document: nil, brand_voice_id: nil)
        body = { 'workspace_id' => workspace_id, 'kind' => kind }
        body.merge!(compact_nil('name' => name, 'document' => document, 'brand_voice_id' => brand_voice_id))
        Design.new(unwrap(http.post('/designs', body)))
      end

      def get(design_id)
        Design.new(unwrap(http.get("/designs/#{design_id}")))
      end

      # Partial update; only the fields you pass are sent. `create_version: true`
      # saves the previous document as a version first.
      def update(design_id, name: UNSET, kind: UNSET, document: UNSET, create_version: UNSET)
        body = compact_unset(
          'name' => name,
          'kind' => kind,
          'document' => document,
          'create_version' => create_version
        )
        Design.new(unwrap(http.patch("/designs/#{design_id}", body)))
      end

      def delete(design_id)
        http.delete("/designs/#{design_id}")
        nil
      end

      # Saved versions, newest first. `include_document: true` adds each document.
      def versions(design_id, include_document: false)
        query = include_document ? { 'include' => 'document' } : nil
        parse_list(DesignVersion, unwrap(http.get("/designs/#{design_id}/versions", query)))
      end

      # Write a saved version back as the current document.
      def restore_version(design_id, version_id)
        Design.new(unwrap(http.post("/designs/#{design_id}/versions/#{version_id}/restore")))
      end

      def duplicate(design_id, name: nil)
        Design.new(unwrap(http.post("/designs/#{design_id}/duplicate", compact_nil('name' => name))))
      end

      # Render pages to the media library. `format` is png, jpg, pdf, mp4 or gif;
      # `duration_sec` (5, 10 or 15) applies to mp4 and gif.
      def export(design_id, format:, page_indexes: nil, duration_sec: nil)
        body = { 'format' => format }
        body.merge!(compact_nil('page_indexes' => page_indexes, 'duration_sec' => duration_sec))
        DesignExport.new(unwrap(http.post("/designs/#{design_id}/export", body)))
      end

      # One new design per row, filling the design's placeholders with the row's
      # values. `name_column` picks the column that names each copy.
      def bulk(design_id, rows:, name_column: nil)
        body = { 'rows' => rows.to_a }
        body.merge!(compact_nil('name_column' => name_column))
        parse_list(Design, unwrap(http.post("/designs/#{design_id}/bulk", body)))
      end

      # Posts that carry one of the design's exports.
      def posts(design_id)
        parse_list(DesignPost, unwrap(http.get("/designs/#{design_id}/posts")))
      end

      # Outline a carousel from `text` or a post's text. Uses AI credits.
      def text_to_slides(workspace_id:, text: nil, post_id: nil, max_slides: nil, brand_voice_id: nil)
        body = { 'workspace_id' => workspace_id }
        body.merge!(
          compact_nil('text' => text, 'post_id' => post_id, 'max_slides' => max_slides,
                      'brand_voice_id' => brand_voice_id)
        )
        SlidesOutline.new(unwrap(http.post('/designs/text-to-slides', body)))
      end

      # A design laid out from `text` or a post. `style` is quote, post or plain.
      def from_post(workspace_id:, text: nil, post_id: nil, style: nil, preset: nil, account_id: nil, carousel: nil,
                    name: nil, brand_voice_id: nil)
        body = { 'workspace_id' => workspace_id }
        body.merge!(
          compact_nil(
            'text' => text,
            'post_id' => post_id,
            'style' => style,
            'preset' => preset,
            'account_id' => account_id,
            'carousel' => carousel,
            'name' => name,
            'brand_voice_id' => brand_voice_id
          )
        )
        Design.new(unwrap(http.post('/designs/from-post', body)))
      end
    end
  end
end
