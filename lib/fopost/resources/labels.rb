# frozen_string_literal: true

module Fopost
  module Resources
    # `client.labels` — workspace labels you can attach to posts.
    class Labels < Base
      def list(workspace_id: nil)
        parse_list(Label, unwrap(http.get('/labels', { 'workspace_id' => workspace_id })))
      end
    end
  end
end
