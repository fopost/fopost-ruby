# frozen_string_literal: true

module Fopost
  # A file handed to `posts.create(files: ...)`: a path, an IO, or a Hash of
  # `filename:` plus `io:` or `data:` and `mime_type:`.
  class FilePart
    MIME_TYPES = {
      'png' => 'image/png', 'jpg' => 'image/jpeg', 'jpeg' => 'image/jpeg', 'gif' => 'image/gif',
      'webp' => 'image/webp', 'heic' => 'image/heic', 'mp4' => 'video/mp4', 'mov' => 'video/quicktime',
      'webm' => 'video/webm', 'm4v' => 'video/x-m4v', 'avi' => 'video/x-msvideo'
    }.freeze

    attr_reader :filename, :mime_type

    def self.from(value)
      case value
      when FilePart then value
      when String then new(filename: File.basename(value), path: value)
      when Hash then from_hash(value)
      else
        raise ArgumentError, "fopost: cannot read a file from #{value.inspect}" unless value.respond_to?(:read)

        new(filename: value.respond_to?(:path) && value.path ? File.basename(value.path) : nil, io: value)
      end
    end

    def self.from_hash(hash)
      hash = hash.transform_keys(&:to_sym)
      new(filename: hash[:filename], mime_type: hash[:mime_type], io: hash[:io], data: hash[:data])
    end

    def initialize(filename:, mime_type: nil, path: nil, io: nil, data: nil)
      raise ArgumentError, 'fopost: a file needs a filename' if filename.nil? || filename.to_s.empty?
      raise ArgumentError, "fopost: a file needs io: or data: (#{filename})" if path.nil? && io.nil? && data.nil?

      @filename = filename.to_s
      @path = path
      @io = io
      @data = data&.b
      @mime_type = mime_type || guess_mime_type
    end

    def size
      return @data.bytesize if @data
      return File.size(@path) if @path
      return @io.size if @io.respond_to?(:size) && @io.size

      data.bytesize
    end

    # The bytes, read once and kept.
    def data
      @data ||= (@path ? File.binread(@path) : @io.read.to_s.b)
    end

    # The post media `type` the API expects for this file.
    def media_type
      return 'gif' if mime_type == 'image/gif'
      return 'video' if mime_type.start_with?('video/')

      'image'
    end

    private

    def guess_mime_type
      extension = File.extname(@filename).delete_prefix('.').downcase
      MIME_TYPES.fetch(extension) do
        raise ArgumentError, "fopost: cannot guess the mime type of #{@filename}; pass mime_type:"
      end
    end
  end
end
