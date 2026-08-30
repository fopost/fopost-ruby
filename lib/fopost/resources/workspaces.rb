# frozen_string_literal: true

module Fopost
  module Resources
    # `client.workspaces` — the workspaces the key can reach.
    class Workspaces < Base
      def list
        parse_list(Workspace, unwrap(http.get('/workspaces')))
      end

      def get(workspace_id)
        Workspace.new(unwrap(http.get("/workspaces/#{workspace_id}")))
      end
    end
  end
end
