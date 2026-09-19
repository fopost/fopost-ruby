# frozen_string_literal: true

module Fopost
  module Resources
    # `client.media` — direct uploads to the media library.
    #
    # A direct upload is three steps: {#presign} reserves a slot, the bytes go
    # straight to `upload_url` with the returned headers, and {#complete}
    # turns the slot into a library item. {#upload_direct} does all three.
    class Media < Base
      # Reserve an upload slot. `size` is the exact byte count of the file.
      def presign(workspace_id:, filename:, mime_type:, size:)
        body = {
          'workspaceId' => workspace_id,
          'filename' => filename,
          'mimeType' => mime_type,
          'size' => size
        }
        PresignedUpload.new(unwrap(http.post('/media/presign', body)))
      end

      # Turn an uploaded slot into a media item.
      def complete(upload_id)
        MediaItem.new(unwrap(http.post("/media/presign/#{upload_id}/complete")))
      end

      # Presign, PUT `data` (a binary String), and complete in one call.
      def upload_direct(workspace_id:, filename:, mime_type:, data:)
        upload = presign(workspace_id: workspace_id, filename: filename, mime_type: mime_type,
                         size: data.bytesize)
        headers = upload.headers.merge('Content-Length' => data.bytesize.to_s)
        http.put_raw(upload.upload_url, data, headers)
        complete(upload.upload_id)
      end
    end
  end
end
