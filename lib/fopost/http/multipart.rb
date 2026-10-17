# frozen_string_literal: true

require 'securerandom'

module Fopost
  module HTTP
    # Encodes a multipart/form-data body from string fields and file parts.
    module Multipart
      Part = Struct.new(:name, :filename, :mime_type, :data, keyword_init: true)

      # Returns `[body, content_type]`; `body` is a binary String.
      def self.encode(fields, parts)
        boundary = "fopost#{SecureRandom.hex(16)}"
        body = String.new(encoding: Encoding::BINARY)

        fields.each do |name, value|
          body << "--#{boundary}\r\n"
          body << "Content-Disposition: form-data; name=\"#{name}\"\r\n\r\n"
          body << value.to_s.b << "\r\n"
        end

        parts.each do |part|
          body << "--#{boundary}\r\n"
          body << "Content-Disposition: form-data; name=\"#{part.name}\"; filename=\"#{quote(part.filename)}\"\r\n"
          body << "Content-Type: #{part.mime_type}\r\n\r\n"
          body << part.data.b << "\r\n"
        end

        body << "--#{boundary}--\r\n"
        [body, "multipart/form-data; boundary=#{boundary}"]
      end

      def self.quote(value)
        value.to_s.gsub(/["\r\n]/, '"' => '%22', "\r" => '', "\n" => '')
      end
    end
  end
end
