# frozen_string_literal: true

module Fopost
  module Resources
    # `client.connect_sessions` — hosted connect links: a URL your own user
    # opens to connect their account to your workspace. Needs the `accounts` scope.
    class ConnectSessions < Base
      # `external_user_id` is your id for the person; `platforms` the networks
      # the link offers. `branding` is `{ name:, logo_url: }`.
      def create(external_user_id:, platforms:, workspace_id: nil, redirect_url: nil, branding: nil)
        body = { 'externalUserId' => external_user_id, 'platforms' => platforms.to_a }
        body.merge!(
          compact_nil(
            'workspaceId' => workspace_id,
            'redirectUrl' => redirect_url,
            'branding' => branding_body(branding)
          )
        )
        ConnectSession.new(unwrap(http.post('/connect-sessions', body)))
      end

      # Poll this to learn when the link was used; `account_id` is set then.
      def get(session_id)
        ConnectSession.new(unwrap(http.get("/connect-sessions/#{session_id}")))
      end

      private

      def branding_body(branding)
        return nil if branding.nil?

        branding = branding.transform_keys(&:to_s)
        compact_nil('name' => branding['name'], 'logoUrl' => branding['logo_url'] || branding['logoUrl'])
      end
    end
  end
end
