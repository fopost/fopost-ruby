# frozen_string_literal: true

module Fopost
  module Resources
    # `client.labels` — workspace labels you can attach to posts.
    class Labels < Base
      def list(workspace_id: nil)
        parse_list(Label, unwrap(http.get('/labels', { 'workspace_id' => workspace_id })))
      end

      # `color` is a hex string such as "#4F46E5".
      def create(workspace_id:, name:, color:)
        body = { 'workspace_id' => workspace_id, 'name' => name, 'color' => color }
        Label.new(unwrap(http.post('/labels', body)))
      end

      def get(label_id)
        Label.new(unwrap(http.get("/labels/#{label_id}")))
      end

      # Both fields are required: the label is replaced, not patched.
      def update(label_id, name:, color:)
        Label.new(unwrap(http.put("/labels/#{label_id}", { 'name' => name, 'color' => color })))
      end

      def delete(label_id)
        http.delete("/labels/#{label_id}")
        nil
      end
    end
  end
end
