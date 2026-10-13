# frozen_string_literal: true

module Fopost
  module Resources
    # `client.media` — direct uploads to the media library.
    #
    # A direct upload is three steps: {#presign} reserves a slot, the bytes go
    # straight to `upload_url` with the returned headers, and {#complete}
    # turns the slot into a library item. {#upload_direct} does all three.
    class Media < Base
      # What a multipart request carries per file when `/media/limits` cannot be read.
      DEFAULT_MULTIPART_MAX_FILE_BYTES = 100 * 1024 * 1024

      # The upload ceilings for the account, by connected accounts or add-on.
      def limits(workspace_id: nil)
        UploadLimits.new(unwrap(http.get('/media/limits', { 'workspaceId' => workspace_id })))
      end

      # Reserve an upload slot. `size` is the exact byte count of the file, up
      # to the account's `max_file_bytes`.
      def presign(workspace_id:, filename:, mime_type:, size:, folder_id: nil, origin: nil, brand_role: nil,
                  brand_voice_id: nil, person_consent: nil)
        body = {
          'workspaceId' => workspace_id,
          'filename' => filename,
          'mimeType' => mime_type,
          'size' => size
        }
        body.merge!(
          compact_nil(
            'folderId' => folder_id,
            'origin' => origin,
            'brandRole' => brand_role,
            'brandVoiceId' => brand_voice_id,
            'personConsent' => person_consent
          )
        )
        PresignedUpload.new(unwrap(http.post('/media/presign', body)))
      end

      # Turn an uploaded slot into a media item.
      def complete(upload_id)
        MediaItem.new(unwrap(http.post("/media/presign/#{upload_id}/complete")))
      end

      # Presign, PUT `data` (a binary String), and complete in one call.
      def upload_direct(workspace_id:, filename:, mime_type:, data:, **presign_options)
        upload = presign(workspace_id: workspace_id, filename: filename, mime_type: mime_type,
                         size: data.bytesize, **presign_options)
        headers = upload.headers.merge('Content-Length' => data.bytesize.to_s)
        http.put_raw(upload.upload_url, data, headers)
        complete(upload.upload_id)
      end
    end
  end
end
