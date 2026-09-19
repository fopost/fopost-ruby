# frozen_string_literal: true

require 'cgi'

module Fopost
  module Resources
    # `client.analytics` — deeper posting analytics.
    #
    # Derived from the repeated readings the platform collector takes of every
    # post as it ages. Every call needs the `analytics` scope.
    class Analytics < Base
      # How engagement accumulates with a post's age, and where the half-life
      # falls. `days` selects posts by publish time, not reading time.
      def decay(days: nil, workspace_id: nil, account_id: nil)
        query = compact_nil('days' => days, 'workspace_id' => workspace_id, 'accountId' => account_id)
        ContentDecay.new(unwrap(http.get('/analytics/decay', query)))
      end

      # Weekly posting cadence set against what each cadence earned per post.
      def frequency(days: nil, workspace_id: nil, account_id: nil)
        query = compact_nil('days' => days, 'workspace_id' => workspace_id, 'accountId' => account_id)
        PostingFrequency.new(unwrap(http.get('/analytics/frequency', query)))
      end

      # Every reading held for one post, oldest first, one timeline per
      # delivery. `id_or_permalink` is a FoPost post id or the permalink of a
      # post made natively on the network.
      def timeline(id_or_permalink)
        path = "/analytics/posts/#{CGI.escape(id_or_permalink.to_s)}/timeline"
        PostTimeline.new(unwrap(http.get(path)))
      end

      # Readings recorded after `since`, oldest first, with a cursor to
      # continue. Poll this to mirror the metrics into your own store; omitting
      # `since` gives the last seven days.
      def changes(since: nil, limit: nil, workspace_id: nil, account_id: nil)
        query = compact_nil(
          'since' => iso8601(since),
          'limit' => limit,
          'workspace_id' => workspace_id,
          'accountId' => account_id
        )
        MetricChangePage.new(unwrap(http.get('/analytics/changes', query)))
      end

      # Re-read one post from the network now. Spends the same per-user budget
      # as a full collection run, so a burst answers 429 with `retryAfter`.
      def collect_post(id_or_permalink)
        path = "/posts/#{CGI.escape(id_or_permalink.to_s)}/analytics/collect"
        CollectPostResult.new(unwrap(http.post(path)))
      end

      # Posts on the account that never went out through FoPost, newest first.
      def native_posts(account_id, page: 1, per_page: 20, days: nil)
        query = compact_nil('page' => page, 'per_page' => per_page, 'days' => days)
        body = http.get("/accounts/#{account_id}/native-posts", query)
        items = parse_list(NativePost, body.is_a?(Hash) ? body['data'] : body)
        raw_meta = body.is_a?(Hash) ? body['meta'] : nil
        Page.new(items: items, meta: InboxPageMeta.new(raw_meta.is_a?(Hash) ? raw_meta : {}))
      end
    end
  end
end
