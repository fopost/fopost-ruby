# frozen_string_literal: true

require 'test_helper'

class AnalyticsTest < Minitest::Test
  include ClientHelpers

  def test_decay_reads_the_bands_and_half_life
    transport.stub(:get, '/analytics/decay', json: {
                     'data' => {
                       'days' => 30,
                       'postsMeasured' => 2,
                       'halfLifeBucket' => '1h_3h',
                       'bands' => [
                         { 'bucket' => 'under_1h', 'label' => 'First hour', 'posts' => 2,
                           'avgEngagements' => 25, 'avgImpressions' => 300, 'shareOfFinal' => 0.3 },
                         { 'bucket' => '6h_12h', 'label' => '6-12 hours', 'posts' => 0,
                           'avgEngagements' => 0, 'avgImpressions' => 0, 'shareOfFinal' => nil }
                       ]
                     }
                   })

    decay = client.analytics.decay(days: 30, account_id: 'acc_1')

    assert_equal '/v1/analytics/decay', transport.last.path
    assert_equal({ 'days' => '30', 'accountId' => 'acc_1' }, transport.last.query)
    assert_equal '1h_3h', decay.half_life_bucket
    assert_equal 2, decay.posts_measured
    assert_in_delta 0.3, decay.bands.first.share_of_final
    # A band nothing was measured in reports no share rather than zero
    assert_nil decay.bands.last.share_of_final
  end

  def test_frequency_reads_the_weeks_and_best_cadence
    transport.stub(:get, '/analytics/frequency', json: {
                     'data' => {
                       'days' => 90,
                       'weeks' => [{ 'weekStart' => '2026-03-02', 'posts' => 2, 'engagements' => 240,
                                     'avgEngagementsPerPost' => 120 }],
                       'bands' => [{ 'band' => 'under_3', 'label' => '1-2 a week', 'weeks' => 1, 'posts' => 2,
                                     'avgPostsPerWeek' => 2, 'avgEngagementsPerPost' => 120,
                                     'engagementRate' => 0.12 }],
                       'best' => { 'band' => 'under_3', 'label' => '1-2 a week', 'avgEngagementsPerPost' => 120 }
                     }
                   })

    frequency = client.analytics.frequency(days: 90)

    assert_equal '2026-03-02', frequency.weeks.first.week_start
    assert_in_delta 0.12, frequency.bands.first.engagement_rate
    assert_equal '1-2 a week', frequency.best.label
  end

  def test_timeline_escapes_a_permalink_into_the_path
    transport.stub(:get, '/analytics/posts/https%3A%2F%2Fx.com%2Facme%2Fstatus%2F1/timeline', json: {
                     'data' => {
                       'postId' => nil,
                       'deliveries' => [{
                         'accountId' => 'acc_1', 'platform' => 'twitter', 'username' => 'acme',
                         'externalPostId' => '1', 'postedAt' => '2026-03-02T00:00:00.000Z',
                         'points' => [{
                           'at' => '2026-03-02T00:30:00.000Z', 'ageMinutes' => 30, 'engagements' => 40,
                           'impressions' => 400, 'reach' => nil, 'likes' => 30, 'comments' => nil,
                           'shares' => nil, 'videoViews' => nil,
                           'delta' => { 'impressions' => 400, 'reach' => 0, 'engagements' => 40,
                                        'likes' => 30, 'comments' => 0, 'shares' => 0 }
                         }]
                       }]
                     }
                   })

    timeline = client.analytics.timeline('https://x.com/acme/status/1')

    assert_equal '/v1/analytics/posts/https%3A%2F%2Fx.com%2Facme%2Fstatus%2F1/timeline', transport.last.path
    assert_nil timeline.post_id
    assert_equal 30, timeline.deliveries.first.points.first.age_minutes
    assert_equal 40, timeline.deliveries.first.points.first.delta.engagements
  end

  def test_changes_carries_the_cursor
    transport.stub(:get, '/analytics/changes', json: {
                     'data' => {
                       'since' => '2026-03-02T00:00:00.000Z',
                       'cursor' => '2026-03-02T06:00:00.000Z',
                       'hasMore' => true,
                       'changes' => [{ 'accountId' => 'acc_1', 'platform' => 'twitter', 'externalPostId' => '1',
                                       'postId' => 'post_1', 'postedAt' => '2026-03-02T00:00:00.000Z',
                                       'fetchedAt' => '2026-03-02T06:00:00.000Z', 'impressions' => 900,
                                       'reach' => nil, 'engagements' => 90, 'likes' => 70, 'comments' => 10,
                                       'shares' => 10 }]
                     }
                   })

    page = client.analytics.changes(since: '2026-03-02T00:00:00Z', limit: 100)

    assert_equal({ 'since' => '2026-03-02T00:00:00Z', 'limit' => '100' }, transport.last.query)
    assert page.has_more
    assert_equal 'post_1', page.changes.first.post_id
  end

  def test_collect_post_reports_each_delivery
    transport.stub(:post, '/posts/post_1/analytics/collect', json: {
                     'data' => {
                       'collected' => 1,
                       'deliveries' => [{ 'accountId' => 'acc_1', 'platform' => 'twitter', 'externalPostId' => '1',
                                          'collected' => true, 'fetchedAt' => '2026-03-02T00:30:00.000Z',
                                          'message' => nil }]
                     }
                   })

    result = client.analytics.collect_post('post_1')

    assert_equal '/v1/posts/post_1/analytics/collect', transport.last.path
    assert_equal 1, result.collected
    assert result.deliveries.first.collected
  end

  def test_native_posts_returns_a_page
    transport.stub(:get, '/accounts/acc_1/native-posts', json: {
                     'data' => [{
                       'externalPostId' => '1', 'text' => 'Posted by hand',
                       'permalink' => 'https://x.com/acme/status/1', 'thumbnailUrl' => nil, 'mediaType' => nil,
                       'postedAt' => '2026-03-02T00:00:00.000Z', 'fetchedAt' => '2026-03-02T06:00:00.000Z',
                       'metrics' => { 'impressions' => 900, 'reach' => nil, 'engagements' => 90, 'likes' => 70,
                                      'comments' => 10, 'shares' => 10, 'videoViews' => nil }
                     }],
                     'meta' => { 'page' => 1, 'perPage' => 20, 'total' => 1 }
                   })

    page = client.analytics.native_posts('acc_1')

    assert_equal({ 'page' => '1', 'per_page' => '20' }, transport.last.query)
    assert_equal 1, page.size
    assert_equal 'https://x.com/acme/status/1', page.first.permalink
    assert_equal 90, page.first.metrics.engagements
    assert_equal 1, page.meta.total
  end
end
