# frozen_string_literal: true

module Fopost
  module Resources
    # `client.accounts` — the social accounts connected to a workspace.
    class Accounts < Base
      # Connected accounts, across every workspace unless one is named.
      def list(workspace_id: nil)
        # This endpoint reads a camelCase query param; posts and labels use snake.
        parse_list(SocialAccount, unwrap(http.get('/accounts', { 'workspaceId' => workspace_id })))
      end

      def get(account_id)
        SocialAccount.new(unwrap(http.get("/accounts/#{account_id}")))
      end

      # Token validity and last-check detail for one account.
      def health(account_id)
        as_hash(unwrap(http.get("/accounts/#{account_id}/health")))
      end
    end
  end
end
