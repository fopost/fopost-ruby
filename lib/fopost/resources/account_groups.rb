# frozen_string_literal: true

module Fopost
  module Resources
    # `client.account_groups` — named sets of accounts to post to together.
    class AccountGroups < Base
      def list(workspace_id: nil)
        parse_list(AccountGroup, unwrap(http.get('/account-groups', { 'workspace_id' => workspace_id })))
      end

      def create(workspace_id:, name:, account_ids: nil)
        body = compact_nil('workspace_id' => workspace_id, 'name' => name, 'account_ids' => account_ids&.to_a)
        AccountGroup.new(unwrap(http.post('/account-groups', body)))
      end

      def get(group_id)
        AccountGroup.new(unwrap(http.get("/account-groups/#{group_id}")))
      end

      # Rename the group.
      def update(group_id, name:)
        AccountGroup.new(unwrap(http.request(:patch, "/account-groups/#{group_id}", json: { 'name' => name })))
      end

      def delete(group_id)
        http.delete("/account-groups/#{group_id}")
        nil
      end

      # Replace the group's members with exactly these accounts.
      def set_members(group_id, account_ids)
        body = { 'account_ids' => account_ids.to_a }
        AccountGroup.new(unwrap(http.put("/account-groups/#{group_id}/members", body)))
      end
    end
  end
end
