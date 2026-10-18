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

      # The library, one page at a time. `type` is image, video, gif or
      # document; `url` finds the item stored at that URL.
      def list(workspace_id: nil, folder_id: nil, search: nil, tag: nil, type: nil, url: nil, brand_role: nil,
               brand_voice_id: nil, generation_run_id: nil, origin: nil, shared: nil, page: nil, per_page: nil)
        query = compact_nil(
          'workspace_id' => workspace_id,
          'folder_id' => folder_id,
          'search' => search,
          'tag' => tag,
          'type' => type,
          'url' => url,
          'brand_role' => brand_role,
          'brand_voice_id' => brand_voice_id,
          'generation_run_id' => generation_run_id,
          'origin' => origin,
          'shared' => shared&.to_s,
          'page' => page,
          'per_page' => per_page
        )
        body = as_hash(http.get('/media', query))
        meta = body['meta'].is_a?(Hash) ? body['meta'] : {}
        Page.new(items: parse_list(MediaItem, body['data']), meta: OffsetPageMeta.new(meta))
      end

      # Upload files through the API in one multipart request. `files` are
      # paths, IOs, or `{ filename:, io:/data:, mime_type: }` hashes, each up
      # to `multipart_max_file_bytes`; larger files go through {#upload_direct}.
      def upload(files, workspace_id: nil)
        parts = Array(files).map do |file|
          part = FilePart.from(file)
          HTTP::Multipart::Part.new(name: 'files', filename: part.filename, mime_type: part.mime_type,
                                    data: part.data)
        end
        fields = compact_nil('workspaceId' => workspace_id)
        parse_list(MediaItem, unwrap(http.post_multipart('/media/upload', fields: fields, parts: parts)))
      end

      def delete(media_id)
        http.delete("/media/#{media_id}")
        nil
      end

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
