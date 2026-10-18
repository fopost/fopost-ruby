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

      # `type` is the API's workspace type (BRAND, AGENCY, TEAM, ...);
      # `timezone` and `language` default server-side.
      def create(name:, type: nil, logo: nil, website: nil, timezone: nil, country: nil, description: nil,
                 language: nil)
        body = { 'name' => name }
        body.merge!(
          compact_nil(
            'type' => type,
            'logo' => logo,
            'website' => website,
            'timezone' => timezone,
            'country' => country,
            'description' => description,
            'language' => language
          )
        )
        Workspace.new(unwrap(http.post('/workspaces', body)))
      end

      # Partial update; only the fields you pass are sent. Pass an explicit nil
      # to clear `logo`, `website`, `country`, `description` or `brand_color`.
      def update(workspace_id, name: UNSET, type: UNSET, logo: UNSET, website: UNSET, timezone: UNSET,
                 country: UNSET, description: UNSET, language: UNSET, require_approval: UNSET,
                 ai_alt_text_enabled: UNSET, brand_color: UNSET, connect_redirect_domains: UNSET)
        body = compact_unset(
          'name' => name,
          'type' => type,
          'logo' => logo,
          'website' => website,
          'timezone' => timezone,
          'country' => country,
          'description' => description,
          'language' => language,
          'requireApproval' => require_approval,
          'aiAltTextEnabled' => ai_alt_text_enabled,
          'brandColor' => brand_color,
          'connectRedirectDomains' => UNSET.equal?(connect_redirect_domains) ? UNSET : connect_redirect_domains&.to_a
        )
        Workspace.new(unwrap(http.put("/workspaces/#{workspace_id}", body)))
      end

      # Deletes the workspace and everything in it. This cannot be undone.
      def delete(workspace_id)
        http.delete("/workspaces/#{workspace_id}")
        nil
      end
    end
  end
end
