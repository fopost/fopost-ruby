# frozen_string_literal: true

require 'test_helper'

class AnalyticsReportsTest < Minitest::Test
  include ClientHelpers

  def test_overview_reads_totals_deltas_and_accounts
    transport.stub(:get, '/analytics/overview', json: {
                     'total_accounts' => 2, 'total_followers' => 1200, 'total_posts' => 30, 'total_engagement' => 400,
                     'total_impressions' => 9000, 'engagement_rate' => 0.044,
                     'deltas' => { 'followers' => 3.5, 'posts' => nil },
                     'today_stats' => { 'posts' => 1, 'follower_change' => 4, 'engagement' => 12 },
                     'platforms' => [{ 'platform' => 'twitter', 'accounts' => 1, 'followers' => 800 }],
                     'accounts' => [{ 'account_id' => 'acc_1', 'platform' => 'twitter', 'username' => 'yourbrand',
                                      'name' => 'Your Brand', 'avatar' => nil, 'followers' => 800,
                                      'total_posts' => 20, 'fetched_at' => '2026-10-01T10:00:00.000Z',
                                      'history' => [{ 'date' => '2026-10-01', 'followers' => 800 }] }]
                   })

    overview = client.analytics.overview(workspace_id: 'ws_1', days: 30)

    assert_equal({ 'workspace_id' => 'ws_1', 'days' => '30' }, transport.last.query)
    assert_equal 1200, overview.total_followers
    assert_in_delta 3.5, overview.deltas.followers
    assert_nil overview.deltas.posts
    assert_equal 4, overview.today_stats.follower_change
    assert_equal 'twitter', overview.platforms[0].platform
    assert_equal 800, overview.accounts[0].history[0].followers
  end

  def test_time_series_top_posts_labels_and_streak
    transport
      .stub(:get, '/analytics/time-series', json: {
              'days' => 7, 'series' => [{ 'date' => '2026-10-01', 'engagements' => 10, 'followers' => 800 }]
            })
      .stub(:get, '/analytics/top-posts', json: {
              'data' => [{ 'rank' => 1, 'post_id' => 'post_1', 'source' => 'fopost', 'preview' => 'Hello',
                           'platforms' => [{ 'platform' => 'twitter', 'username' => 'yourbrand', 'url' => nil,
                                             'removed' => false }],
                           'labels' => [{ 'id' => 'lbl_1', 'name' => 'Launch', 'color' => '#000' }],
                           'metrics' => { 'engagements' => 40, 'impressions' => 400 } }]
            })
      .stub(:get, '/analytics/labels', json: {
              'data' => [{ 'label_id' => 'lbl_1', 'name' => 'Launch', 'color' => '#000', 'post_count' => 3,
                           'engagements' => 90, 'engagement_rate' => 0.1, 'follower_delta' => nil }]
            })
      .stub(:get, '/analytics/posting-streak', json: {
              'streak' => [{ 'date' => '2026-10-01', 'count' => 2, 'published_count' => 2, 'failed_count' => 0,
                             'scheduled_count' => 0 }]
            })

    series = client.analytics.time_series(from: Time.utc(2026, 10, 1), to: '2026-10-07')

    assert_equal({ 'from' => '2026-10-01T00:00:00Z', 'to' => '2026-10-07' }, transport.last.query)
    assert_equal 7, series.days
    assert_equal 10, series.series[0].engagements

    top = client.analytics.top_posts(limit: 5, sort: 'recent', label: 'lbl_1')

    assert_equal({ 'limit' => '5', 'sort' => 'recent', 'label' => 'lbl_1' }, transport.last.query)
    assert_equal 40, top[0].metrics.engagements
    assert_equal 'Launch', top[0].labels[0].name
    refute top[0].platforms[0].removed

    labels = client.analytics.labels(days: 30)

    assert_equal 3, labels[0].post_count
    assert_nil labels[0].follower_delta

    streak = client.analytics.posting_streak(workspace_id: 'ws_1')

    assert_equal 2, streak.streak[0].published_count
  end

  def test_posts_table_demographics_inbox_and_collect
    transport
      .stub(:get, '/analytics/posts-table', json: {
              'data' => [{ 'post_id' => 'post_1', 'preview' => 'Hello', 'status' => 'published',
                           'platforms' => [{ 'platform' => 'twitter', 'username' => 'yourbrand', 'url' => nil,
                                             'delivery_status' => 'published' }],
                           'delivery_summary' => { 'total' => 1, 'published' => 1, 'failed' => 0, 'pending' => 0 } }],
              'meta' => { 'page' => 2, 'per_page' => 10, 'total' => 11, 'total_pages' => 2 },
              'summary' => { 'draft' => 1, 'scheduled' => 0, 'published' => 10, 'failed' => 0, 'pending' => 0,
                             'total' => 11 }
            })
      .stub(:get, '/analytics/demographics', json: {
              'audience' => 'followers',
              'dimensions' => { 'age' => [{ 'key' => '25-34', 'value' => 300, 'share' => 0.4 }], 'gender' => [],
                                'country' => [], 'city' => [] },
              'contributing_accounts' => [{ 'account_id' => 'acc_1', 'platform' => 'instagram',
                                            'username' => 'yourbrand' }],
              'unsupported_accounts' => []
            })
      .stub(:get, '/analytics/inbox', json: {
              'totals' => { 'received' => 20, 'sent' => 15, 'answered' => 12, 'open' => 3, 'conversations' => 9,
                            'median_response_minutes' => 42.5 },
              'deltas' => { 'received' => 10.0 },
              'series' => [{ 'date' => '2026-10-01', 'received' => 2, 'sent' => 1, 'answered' => 1 }],
              'by_platform' => [{ 'platform' => 'twitter', 'received' => 20, 'sent' => 15 }],
              'by_type' => [{ 'type' => 'comment', 'count' => 20 }],
              'by_account' => [],
              'response_time' => [{ 'bucket' => 'under_1h', 'count' => 8 }],
              'heatmap' => [{ 'weekday' => 1, 'hour' => 9, 'count' => 4 }],
              'time_zone' => 'Europe/Zagreb'
            })
      .stub(:post, '/analytics/collect', json: {
              'accounts' => 2, 'posts' => 30, 'demographics' => 1, 'errors' => 1,
              'error_details' => [{ 'account_id' => 'acc_2', 'platform' => 'twitter', 'username' => 'yourbrand',
                                    'stage' => 'account', 'message' => 'balance spent', 'action' => 'fund' }]
            })

    table = client.analytics.posts_table(page: 2, per_page: 10)

    assert_equal({ 'page' => '2', 'per_page' => '10' }, transport.last.query)
    assert_equal 'published', table.rows[0].platforms[0].delivery_status
    assert_equal 1, table.rows[0].delivery_summary.published
    assert_equal 2, table.meta.total_pages
    assert_equal 11, table.summary.total

    demographics = client.analytics.demographics(audience: 'followers', account_id: 'acc_1')

    assert_equal({ 'account_id' => 'acc_1', 'audience' => 'followers' }, transport.last.query)
    assert_in_delta 0.4, demographics.dimensions.age[0].share
    assert_equal 'instagram', demographics.contributing_accounts[0].platform

    inbox = client.analytics.inbox(days: 30, tz: 'Europe/Zagreb')

    assert_equal({ 'days' => '30', 'tz' => 'Europe/Zagreb' }, transport.last.query)
    assert_in_delta 42.5, inbox.totals.median_response_minutes
    assert_equal 'under_1h', inbox.response_time[0].bucket
    assert_equal 9, inbox.heatmap[0].hour

    collected = client.analytics.collect(workspace_id: 'ws_1')

    assert_equal 'POST', transport.last.method
    assert_equal '/v1/analytics/collect', transport.last.path
    assert_equal({ 'workspace_id' => 'ws_1' }, transport.last.query)
    assert_equal 'fund', collected.error_details[0].action
  end
end
