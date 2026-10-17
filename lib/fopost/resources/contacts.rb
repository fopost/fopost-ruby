# frozen_string_literal: true

module Fopost
  module Resources
    # `client.contacts` — the people behind the inbox, and the fields your
    # workspace keeps about them.
    #
    # A contact is one human however many handles they write from. An inbound
    # inbox item files its author, a reply files whoever you answered, and both
    # fold into whatever is already on file. Every method needs the `inbox`
    # scope, except {#conversation_analytics}, which needs `analytics`.
    class Contacts < Base
      # One page of contacts, most recently active first. The result is
      # Enumerable over its items.
      #
      # Omit `workspace_id` to span every workspace the key can reach; each
      # contact then carries `workspace_id`.
      def list(workspace_id: nil, search: nil, platform: nil, source: nil, page: 1, per_page: 25)
        body = http.get(
          '/contacts',
          {
            'workspace_id' => workspace_id,
            'search' => search,
            'platform' => platform,
            'source' => source,
            'page' => page,
            'per_page' => per_page
          }
        )
        hash = as_hash(body)
        raw_meta = hash['pagination']
        Page.new(
          items: parse_list(Contact, hash['data']),
          meta: ContactPageMeta.new(raw_meta.is_a?(Hash) ? raw_meta : {})
        )
      end

      def get(contact_id)
        Contact.new(unwrap(http.get("/contacts/#{contact_id}")))
      end

      # Create a contact.
      #
      # Folds into the contact that already holds the first channel, so this
      # cannot duplicate someone the inbox has already met.
      def create(workspace_id:, channels:, display_name: nil, note: nil, fields: nil)
        body = compact_nil(
          'workspace_id' => workspace_id,
          'channels' => channels,
          'display_name' => display_name,
          'note' => note,
          'fields' => fields
        )
        Contact.new(unwrap(http.post('/contacts', body)))
      end

      # Partial update: only what you pass is sent. A custom field set to nil
      # is cleared.
      def update(contact_id, display_name: UNSET, channels: UNSET, note: UNSET, fields: UNSET)
        body = compact_unset(
          'display_name' => display_name,
          'channels' => channels,
          'note' => note,
          'fields' => fields
        )
        Contact.new(unwrap(http.request(:patch, "/contacts/#{contact_id}", json: body)))
      end

      # Removes a contact. Their messages stay in the inbox and file them again.
      def delete(contact_id)
        http.delete("/contacts/#{contact_id}")
        nil
      end

      # The threads this person appears in, newest first.
      def conversations(contact_id, limit: nil)
        parse_list(
          ContactConversation,
          unwrap(http.get("/contacts/#{contact_id}/conversations", { 'limit' => limit }))
        )
      end

      # Import from CSV text.
      #
      # `platform` and `handle` are required columns. Any other column is read
      # as a custom field key, and one matching no field comes back in
      # `unknown_columns` rather than being stored.
      def import(workspace_id:, csv:)
        ContactImportResult.new(
          unwrap(http.post('/contacts/import', { 'workspace_id' => workspace_id, 'csv' => csv }))
        )
      end

      # The columns this workspace keeps about its contacts, in display order.
      def list_fields(workspace_id)
        parse_list(ContactField, unwrap(http.get('/contacts/fields', { 'workspace_id' => workspace_id })))
      end

      def create_field(workspace_id:, key:, name:, type: 'text', options: [])
        ContactField.new(unwrap(http.request(
                                  :post,
                                  '/contacts/fields',
                                  json: { 'key' => key, 'name' => name, 'type' => type, 'options' => options },
                                  params: { 'workspace_id' => workspace_id }
                                )))
      end

      # The key and the type are fixed once created; the name and options are not.
      def update_field(field_id, name: UNSET, options: UNSET, position: UNSET)
        body = compact_unset('name' => name, 'options' => options, 'position' => position)
        ContactField.new(unwrap(http.request(:patch, "/contacts/fields/#{field_id}", json: body)))
      end

      # Removes the field and every answer to it.
      def delete_field(field_id)
        http.delete("/contacts/fields/#{field_id}")
        nil
      end

      # Volume and median reply time per thread. Needs the `analytics` scope.
      def conversation_analytics(workspace_id: nil, account_id: nil, days: nil, sort: nil, page: 1, per_page: 25)
        ConversationAnalytics.new(unwrap(http.get(
                                           '/analytics/inbox/conversations',
                                           {
                                             'workspace_id' => workspace_id,
                                             'accountId' => account_id,
                                             'days' => days,
                                             'sort' => sort,
                                             'page' => page,
                                             'per_page' => per_page
                                           }
                                         )))
      end
    end
  end
end
