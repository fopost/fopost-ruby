# frozen_string_literal: true

require 'cgi'

module Fopost
  module Resources
    # `client.analytics` — deeper posting analytics.
    #
    # Derived from the repeated readings the platform collector takes of every
    # post as it ages. Every call needs the `analytics` scope.
    class Analytics < Base
      # Totals, deltas against the previous window, and per-account follower history.
      def overview(workspace_id: nil, account_id: nil, days: nil)
        query = compact_nil('workspace_id' => workspace_id, 'account_id' => account_id, 'days' => days)
        AnalyticsOverview.new(unwrap(http.get('/analytics/overview', query)))
      end

      # One point per day. `from`/`to` bound the range instead of `days`.
      def time_series(workspace_id: nil, account_id: nil, days: nil, from: nil, to: nil)
        query = compact_nil(
          'workspace_id' => workspace_id,
          'account_id' => account_id,
          'days' => days,
          'from' => iso8601(from),
          'to' => iso8601(to)
        )
        AnalyticsTimeSeries.new(unwrap(http.get('/analytics/time-series', query)))
      end

      # Posts ranked by engagement; `sort: 'recent'` orders by date instead.
      def top_posts(workspace_id: nil, account_id: nil, limit: nil, days: nil, from: nil, to: nil, sort: nil,
                    label: nil)
        query = compact_nil(
          'workspace_id' => workspace_id,
          'account_id' => account_id,
          'limit' => limit,
          'days' => days,
          'from' => iso8601(from),
          'to' => iso8601(to),
          'sort' => sort,
          'label' => label
        )
        parse_list(TopPost, unwrap(http.get('/analytics/top-posts', query)))
      end

      # What each label earned across the posts wearing it.
      def labels(workspace_id: nil, account_id: nil, days: nil, from: nil, to: nil)
        query = compact_nil(
          'workspace_id' => workspace_id,
          'account_id' => account_id,
          'days' => days,
          'from' => iso8601(from),
          'to' => iso8601(to)
        )
        parse_list(LabelAnalytics, unwrap(http.get('/analytics/labels', query)))
      end

      # Posts with their delivery breakdown, one page at a time, plus the
      # status counts across the whole range.
      def posts_table(workspace_id: nil, account_id: nil, page: nil, per_page: nil, days: nil, from: nil, to: nil)
        query = compact_nil(
          'workspace_id' => workspace_id,
          'account_id' => account_id,
          'page' => page,
          'per_page' => per_page,
          'days' => days,
          'from' => iso8601(from),
          'to' => iso8601(to)
        )
        body = as_hash(http.get('/analytics/posts-table', query))
        PostsTable.new('rows' => body['data'], 'meta' => body['meta'], 'summary' => body['summary'])
      end

      # One row per day over the last 365 days.
      def posting_streak(workspace_id: nil)
        PostingStreak.new(unwrap(http.get('/analytics/posting-streak', compact_nil('workspace_id' => workspace_id))))
      end

      # Age, gender, country and city of `audience` ('followers', 'engaged' or
      # 'reached'), from the accounts whose network reports them.
      def demographics(workspace_id: nil, account_id: nil, audience: nil)
        query = compact_nil('workspace_id' => workspace_id, 'account_id' => account_id, 'audience' => audience)
        AudienceDemographics.new(unwrap(http.get('/analytics/demographics', query)))
      end

      # Volume, response time and the busiest hours of the inbox. `tz` names
      # the time zone the heatmap and series are bucketed in.
      def inbox(workspace_id: nil, account_id: nil, days: nil, tz: nil)
        query = compact_nil('workspace_id' => workspace_id, 'account_id' => account_id, 'days' => days, 'tz' => tz)
        InboxAnalytics.new(unwrap(http.get('/analytics/inbox', query)))
      end

      # Run a collection now instead of waiting for the next scheduled one.
      def collect(workspace_id: nil, account_id: nil)
        query = compact_nil('workspace_id' => workspace_id, 'account_id' => account_id)
        AnalyticsCollectResult.new(unwrap(http.request(:post, '/analytics/collect', params: query)))
      end

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
