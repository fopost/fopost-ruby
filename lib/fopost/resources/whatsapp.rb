# frozen_string_literal: true

module Fopost
  module Resources
    # `client.whatsapp` — a WhatsApp Business connection.
    #
    # The platform owns templates, flows, the profile and the commerce settings,
    # so every method here is a live read or write against the customer's own
    # WhatsApp Business Account. All of it answers 503 until WhatsApp is set up.
    class Whatsapp < Base
      # ─── Profile ─────────────────────────────────────────────────

      def profile(account_id)
        WhatsappProfile.new(unwrap(http.get("/accounts/#{account_id}/whatsapp/profile")))
      end

      def update_profile(account_id, about: UNSET, address: UNSET, description: UNSET,
                         vertical: UNSET, websites: UNSET, profile_picture_media_id: UNSET)
        body = compact_unset(
          'about' => about,
          'address' => address,
          'description' => description,
          'vertical' => vertical,
          'websites' => websites,
          'profile_picture_media_id' => profile_picture_media_id
        )
        WhatsappProfile.new(unwrap(http.request(:patch, "/accounts/#{account_id}/whatsapp/profile", json: body)))
      end

      # A review, not a write: the number keeps its old name until it passes.
      def request_display_name(account_id, display_name)
        body = { 'display_name' => display_name }
        as_hash(unwrap(http.post("/accounts/#{account_id}/whatsapp/profile/display-name", body)))
      end

      def set_username(account_id, username)
        body = { 'username' => username }
        WhatsappProfile.new(unwrap(http.put("/accounts/#{account_id}/whatsapp/profile/username", body)))
      end

      # ─── Templates ───────────────────────────────────────────────

      def templates(account_id, after: nil)
        params = compact_nil('after' => after)
        parse_list(WhatsappTemplate, unwrap(http.get("/accounts/#{account_id}/whatsapp/templates", params)))
      end

      # The platform's pre-written templates, for adapting instead of drafting.
      def template_library(account_id, search: nil)
        params = compact_nil('search' => search)
        body = unwrap(http.get("/accounts/#{account_id}/whatsapp/templates/library", params))
        body.is_a?(Array) ? body : []
      end

      def template(account_id, template_id)
        WhatsappTemplate.new(unwrap(http.get("/accounts/#{account_id}/whatsapp/templates/#{template_id}")))
      end

      # Files a template for review; the result carries the status it was given.
      def create_template(account_id, name:, language:, category:, components:,
                          allow_category_change: nil)
        body = compact_nil(
          'name' => name,
          'language' => language,
          'category' => category,
          'components' => components.map { |c| c.transform_keys(&:to_s) },
          'allow_category_change' => allow_category_change
        )
        WhatsappTemplate.new(unwrap(http.post("/accounts/#{account_id}/whatsapp/templates", body)))
      end

      def import_template(account_id, library_template_name:, name:, language:, category:,
                          library_template_button_inputs: nil)
        body = compact_nil(
          'library_template_name' => library_template_name,
          'name' => name,
          'language' => language,
          'category' => category,
          'library_template_button_inputs' => library_template_button_inputs
        )
        WhatsappTemplate.new(unwrap(http.post("/accounts/#{account_id}/whatsapp/templates/import", body)))
      end

      def update_template(account_id, template_id, category: nil, components: nil)
        body = compact_nil('category' => category, 'components' => components)
        path = "/accounts/#{account_id}/whatsapp/templates/#{template_id}"
        WhatsappTemplate.new(unwrap(http.request(:patch, path, json: body)))
      end

      # The name is required: it is what the platform deletes by.
      def delete_template(account_id, template_id, name:)
        query = URI.encode_www_form('name' => name)
        as_hash(unwrap(http.delete("/accounts/#{account_id}/whatsapp/templates/#{template_id}?#{query}")))
      end

      # ─── Groups ──────────────────────────────────────────────────

      def groups(account_id)
        parse_list(WhatsappGroup, unwrap(http.get("/accounts/#{account_id}/whatsapp/groups")))
      end

      # Participation is invite-only: send the invite link, there is no add.
      def create_group(account_id, subject:, description: nil)
        body = compact_nil('subject' => subject, 'description' => description)
        WhatsappGroup.new(unwrap(http.post("/accounts/#{account_id}/whatsapp/groups", body)))
      end

      def group(account_id, group_id)
        WhatsappGroup.new(unwrap(http.get("/accounts/#{account_id}/whatsapp/groups/#{group_id}")))
      end

      def update_group(account_id, group_id, subject: nil, description: nil)
        body = compact_nil('subject' => subject, 'description' => description)
        path = "/accounts/#{account_id}/whatsapp/groups/#{group_id}"
        WhatsappGroup.new(unwrap(http.request(:patch, path, json: body)))
      end

      def delete_group(account_id, group_id)
        as_hash(unwrap(http.delete("/accounts/#{account_id}/whatsapp/groups/#{group_id}")))
      end

      def group_invite_link(account_id, group_id)
        body = as_hash(unwrap(http.get("/accounts/#{account_id}/whatsapp/groups/#{group_id}/invite-link")))
        body['inviteLink']
      end

      # Issues a new link and invalidates the old one.
      def reset_group_invite_link(account_id, group_id)
        body = as_hash(unwrap(http.post("/accounts/#{account_id}/whatsapp/groups/#{group_id}/invite-link")))
        body['inviteLink']
      end

      def remove_group_participants(account_id, group_id, users)
        path = "/accounts/#{account_id}/whatsapp/groups/#{group_id}/participants"
        as_hash(unwrap(http.delete(path, { 'users' => users.to_a })))
      end

      # ─── Blocking ────────────────────────────────────────────────

      def blocked(account_id, after: nil)
        params = compact_nil('after' => after)
        body = unwrap(http.get("/accounts/#{account_id}/whatsapp/block", params))
        body.is_a?(Array) ? body : []
      end

      def block_users(account_id, users)
        body = { 'users' => users.to_a }
        WhatsappBlockResult.new(unwrap(http.post("/accounts/#{account_id}/whatsapp/block", body)))
      end

      def unblock_users(account_id, users)
        body = { 'users' => users.to_a }
        WhatsappBlockResult.new(unwrap(http.delete("/accounts/#{account_id}/whatsapp/block", body)))
      end

      # ─── Commerce ────────────────────────────────────────────────

      def commerce_settings(account_id)
        WhatsappCommerceSettings.new(unwrap(http.get("/accounts/#{account_id}/whatsapp/commerce")))
      end

      def update_commerce_settings(account_id, cart_enabled: nil, catalog_visible: nil)
        body = compact_nil('is_cart_enabled' => cart_enabled, 'is_catalog_visible' => catalog_visible)
        path = "/accounts/#{account_id}/whatsapp/commerce"
        WhatsappCommerceSettings.new(unwrap(http.request(:patch, path, json: body)))
      end

      def link_catalog(account_id, catalog_id)
        body = { 'catalog_id' => catalog_id }
        path = "/accounts/#{account_id}/whatsapp/commerce/catalog"
        WhatsappCommerceSettings.new(unwrap(http.post(path, body)))
      end

      # ─── Flows ───────────────────────────────────────────────────

      def flows(account_id)
        parse_list(WhatsappFlow, unwrap(http.get("/accounts/#{account_id}/whatsapp/flows")))
      end

      def flow(account_id, flow_id)
        WhatsappFlow.new(unwrap(http.get("/accounts/#{account_id}/whatsapp/flows/#{flow_id}")))
      end

      def create_flow(account_id, name:, categories:, endpoint_uri: nil, clone_flow_id: nil)
        body = compact_nil(
          'name' => name,
          'categories' => categories.to_a,
          'endpoint_uri' => endpoint_uri,
          'clone_flow_id' => clone_flow_id
        )
        WhatsappFlow.new(unwrap(http.post("/accounts/#{account_id}/whatsapp/flows", body)))
      end

      def update_flow(account_id, flow_id, name: nil, categories: nil, endpoint_uri: nil)
        body = compact_nil('name' => name, 'categories' => categories, 'endpoint_uri' => endpoint_uri)
        path = "/accounts/#{account_id}/whatsapp/flows/#{flow_id}"
        WhatsappFlow.new(unwrap(http.request(:patch, path, json: body)))
      end

      # Drafts only; a published flow is deprecated instead.
      def delete_flow(account_id, flow_id)
        as_hash(unwrap(http.delete("/accounts/#{account_id}/whatsapp/flows/#{flow_id}")))
      end

      # The platform answers with its validation errors rather than refusing.
      def upload_flow_json(account_id, flow_id, flow_json)
        body = { 'flow_json' => flow_json }
        path = "/accounts/#{account_id}/whatsapp/flows/#{flow_id}/json"
        WhatsappFlowJsonResult.new(unwrap(http.put(path, body)))
      end

      def publish_flow(account_id, flow_id)
        WhatsappFlow.new(unwrap(http.post("/accounts/#{account_id}/whatsapp/flows/#{flow_id}/publish")))
      end

      def deprecate_flow(account_id, flow_id)
        WhatsappFlow.new(unwrap(http.post("/accounts/#{account_id}/whatsapp/flows/#{flow_id}/deprecate")))
      end

      def flow_responses(account_id)
        path = "/accounts/#{account_id}/whatsapp/flows/responses"
        parse_list(WhatsappFlowResponse, unwrap(http.get(path)))
      end

      def encryption_key_status(account_id)
        path = "/accounts/#{account_id}/whatsapp/flows/encryption-key"
        WhatsappEncryptionKeyStatus.new(unwrap(http.get(path)))
      end

      # The public half only; the private half stays with the customer.
      def set_encryption_key(account_id, business_public_key)
        body = { 'business_public_key' => business_public_key }
        path = "/accounts/#{account_id}/whatsapp/flows/encryption-key"
        WhatsappEncryptionKeyStatus.new(unwrap(http.put(path, body)))
      end

      # ─── Account state and sandbox ───────────────────────────────

      def account_events(account_id)
        as_hash(unwrap(http.get("/accounts/#{account_id}/whatsapp/events")))
      end

      def sandbox_sessions(workspace_id:)
        params = { 'workspaceId' => workspace_id }
        parse_list(WhatsappSandboxSession, unwrap(http.get('/whatsapp/sandbox/sessions', params)))
      end

      # Sends a template from the platform-owned test number; needs the publish scope.
      def create_sandbox_session(workspace_id:, phone_number:)
        body = { 'workspaceId' => workspace_id, 'phoneNumber' => phone_number }
        WhatsappSandboxSession.new(unwrap(http.post('/whatsapp/sandbox/sessions', body)))
      end
    end
  end
end
