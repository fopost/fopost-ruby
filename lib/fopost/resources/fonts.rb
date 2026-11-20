# frozen_string_literal: true

module Fopost
  module Resources
    # `client.fonts` — the built-in font library and fonts uploaded to a
    # workspace. Needs the `posts` scope.
    class Fonts < Base
      def list(workspace_id: nil)
        FontList.new(unwrap(http.get('/fonts', compact_nil('workspace_id' => workspace_id))))
      end

      # Upload one font file (ttf, otf, woff or woff2, up to 5 MB). `file` is a
      # path, an IO, or `{ filename:, io:/data:, mime_type: }`. `family`
      # defaults to the file name, `weight` to 400, `style` to normal.
      def upload(file, workspace_id:, family: nil, weight: nil, style: nil)
        part = FilePart.from(file)
        parts = [HTTP::Multipart::Part.new(name: 'file', filename: part.filename, mime_type: part.mime_type,
                                           data: part.data)]
        fields = { 'workspace_id' => workspace_id }
        fields.merge!(compact_nil('family' => family, 'weight' => weight&.to_s, 'style' => style))
        UploadedFont.new(unwrap(http.post_multipart('/fonts', fields: fields, parts: parts)))
      end

      def delete(font_id)
        http.delete("/fonts/#{font_id}")
        nil
      end
    end
  end
end
