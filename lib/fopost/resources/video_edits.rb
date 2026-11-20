# frozen_string_literal: true

module Fopost
  module Resources
    # `client.video_edits` — edit jobs on a video or audio file in the media
    # library. Needs the `posts` scope; AI operations (subtitles, clips,
    # voiceover and the like) also need `ai`. Poll {#get} until `status` is
    # succeeded or failed.
    class VideoEdits < Base
      # Every operation and whether it can run here.
      def ops
        parse_list(VideoEditOp, unwrap(http.get('/video-edits/ops')))
      end

      def list(workspace_id: nil, media_id: nil, limit: nil)
        query = compact_nil('workspace_id' => workspace_id, 'media_id' => media_id, 'limit' => limit)
        parse_list(VideoEdit, unwrap(http.get('/video-edits', query)))
      end

      # `operations` is a list of `{ op:, params: }`, run in order (1 to 10).
      def create(media_id:, operations:, workspace_id: nil)
        body = { 'media_id' => media_id, 'operations' => operations.to_a.map { |operation| operation_body(operation) } }
        body.merge!(compact_nil('workspace_id' => workspace_id))
        VideoEdit.new(unwrap(http.post('/video-edits', body)))
      end

      def get(edit_id, workspace_id: nil)
        VideoEdit.new(unwrap(http.get("/video-edits/#{edit_id}", compact_nil('workspace_id' => workspace_id))))
      end

      private

      def operation_body(operation)
        operation = operation.transform_keys(&:to_s)
        compact_nil('op' => operation['op']&.to_s, 'params' => operation['params'])
      end
    end
  end
end
