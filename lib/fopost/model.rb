# frozen_string_literal: true

require 'time'

module Fopost
  # Base for every response model.
  #
  # The API is not consistent about its wire casing — posts come back
  # snake_case, accounts camelCase, workspaces a mix — so every key is
  # normalised to a snake_case symbol before it is read. Unknown keys are kept
  # on {#raw} rather than dropped, so a server-side addition never breaks a
  # client.
  class Model
    class << self
      def attribute_types
        @attribute_types ||= superclass.respond_to?(:attribute_types) ? superclass.attribute_types.dup : {}
      end

      # `type` is nil (pass through), :time, :hash, a Model subclass, or a
      # one-element array holding a Model subclass.
      def attribute(name, type = nil)
        attribute_types[name] = type
        define_method(name) { @attributes[name] }
      end

      def snake(key)
        key.to_s
           .gsub(/([a-z\d])([A-Z])/, '\1_\2')
           .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
           .downcase
           .to_sym
      end

      def normalize(data)
        return {} unless data.is_a?(Hash)

        data.each_with_object({}) { |(key, value), out| out[snake(key)] = value }
      end

      def coerce(type, value)
        case type
        when nil then value
        when :time then parse_time(value)
        when :hash then value.is_a?(Hash) ? value : {}
        when Array
          member = type.first
          value.is_a?(Array) ? value.map { |item| member.new(item) } : []
        else
          value.is_a?(Hash) ? type.new(value) : nil
        end
      end

      def parse_time(value)
        case value
        when Time then value
        when String then Time.iso8601(value) rescue (Time.parse(value) rescue nil)
        end
      end
    end

    # The decoded body exactly as the API sent it.
    attr_reader :raw

    def initialize(data = {})
      @raw = data.is_a?(Hash) ? data : {}
      normalized = self.class.normalize(@raw)
      @attributes = {}
      self.class.attribute_types.each do |name, type|
        @attributes[name] = self.class.coerce(type, normalized[name])
      end
      @normalized = normalized
    end

    # Read a field the SDK does not model yet, by either wire spelling.
    def [](key)
      name = self.class.snake(key)
      return @attributes[name] if @attributes.key?(name)

      @normalized[name]
    end

    def to_h
      @attributes.dup
    end

    def ==(other)
      other.class == self.class && other.raw == raw
    end
    alias eql? ==

    def hash
      [self.class, raw].hash
    end

    def inspect
      shown = @attributes.reject { |_, value| value.nil? || value == [] || value == {} }
      fields = shown.map { |name, value| "#{name}=#{value.inspect}" }.join(' ')
      "#<#{self.class.name}#{" #{fields}" unless fields.empty?}>"
    end
  end
end
