# frozen_string_literal: true

module Fopost
  module Resources
    # `client.logs` — the API request log, one row per call made with a key
    # or from the dashboard. Needs the `workspaces` scope.
    class Logs < Base
      # Newest first. `status` is 'success' or 'failed'; `before` is the
      # `next_cursor` of the previous page.
      def list(workspace_id: nil, days: nil, status: nil, method: nil, status_code: nil, platform: nil,
               route: nil, q: nil, limit: nil, before: nil)
        query = compact_nil(
          'workspace_id' => workspace_id,
          'days' => days,
          'status' => status,
          'method' => method,
          'status_code' => status_code,
          'platform' => platform,
          'route' => route,
          'q' => q,
          'limit' => limit,
          'before' => before
        )
        body = as_hash(http.get('/logs', query))
        meta = body['meta'].is_a?(Hash) ? body['meta'] : {}
        RequestLogPage.new(
          'logs' => body['data'],
          'next_cursor' => meta['next_cursor'],
          'has_more' => meta['has_more'],
          'summary' => body['summary']
        )
      end
    end
  end
end
