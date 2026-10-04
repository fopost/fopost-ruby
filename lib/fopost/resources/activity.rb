# frozen_string_literal: true

module Fopost
  module Resources
    # `client.activity` — what happened in a workspace, and the audit log.
    class Activity < Base
      # Newest first. Omit `workspace_id` to read every workspace the key can reach.
      #
      # `kind: 'security'` is the audit log: members joining, leaving or changing
      # role and access, and changes to two-step verification, passkeys, single
      # sign-on and signed-in devices. Those rows are append-only and never expire.
      def list(workspace_id: nil, kind: nil, from: nil, to: nil, cursor: nil, limit: nil)
        params = compact_nil(
          'workspace_id' => workspace_id,
          'kind' => kind,
          'from' => iso8601(from),
          'to' => iso8601(to),
          'cursor' => cursor,
          'limit' => limit
        )
        body = as_hash(http.get('/activity', params))
        meta = body['meta'].is_a?(Hash) ? body['meta'] : {}
        ActivityPage.new('events' => body['data'], 'next_cursor' => meta['next_cursor'])
      end
    end
  end
end
