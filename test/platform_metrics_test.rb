# frozen_string_literal: true

require 'test_helper'

class PlatformMetricsTest < Minitest::Test
  include ClientHelpers

  FACEBOOK_SET = {
    'platform' => 'facebook',
    'account' => {
      'fetched_at' => '2026-09-20T02:00:00.000Z',
      'metrics' => [
        { 'key' => 'page_daily_video_ad_break_earnings', 'label' => 'Ad Break Earnings',
          'kind' => 'currency_usd', 'value' => 42.15 },
        { 'key' => 'page_impressions_paid', 'label' => 'Paid Impressions',
          'kind' => 'count', 'value' => 1500 }
      ]
    },
    'post' => {
      'external_post_id' => '123_456',
      'fetched_at' => '2026-09-20T02:00:00.000Z',
      'metrics' => []
    }
  }.freeze

  def test_platform_metrics_asks_for_raw_and_parses_the_set
    transport.stub(:get, '/accounts/acc_1/insights', json: { 'data' => FACEBOOK_SET })

    metrics = client.accounts.platform_metrics('acc_1')

    assert_equal({ 'raw' => 'true' }, transport.last.query)
    assert_equal 'facebook', metrics.platform
    assert_equal '2026-09-20T02:00:00.000Z', metrics.account.fetched_at
    assert_equal %w[page_daily_video_ad_break_earnings page_impressions_paid],
                 metrics.account.metrics.map(&:key)
    assert_in_delta 42.15, metrics.account.metrics[0].value
    assert_equal 'currency_usd', metrics.account.metrics[0].kind
    assert_equal '123_456', metrics.post.external_post_id
    assert_empty metrics.post.metrics
  end

  def test_a_series_value_survives_as_an_array
    transport.stub(:get, '/accounts/acc_1/insights', json: {
                     'data' => {
                       'platform' => 'youtube',
                       'account' => {
                         'fetched_at' => nil,
                         'metrics' => [
                           { 'key' => 'daily_views', 'label' => 'Views by Day', 'kind' => 'series',
                             'value' => [{ 'day' => '2026-09-19', 'views' => 600 }] }
                         ]
                       },
                       'post' => { 'external_post_id' => nil, 'fetched_at' => nil, 'metrics' => [] }
                     }
                   })

    metrics = client.accounts.platform_metrics('acc_1')

    assert_equal [{ 'day' => '2026-09-19', 'views' => 600 }], metrics.account.metrics[0].value
    assert_nil metrics.account.fetched_at
  end

  def test_a_pending_metric_grant_raises
    transport.stub(:get, '/accounts/acc_1/insights', status: 503, json: {
                     'error' => 'platform_metrics_unavailable',
                     'message' => 'google-business metrics are not available on this deployment yet.'
                   })

    error = assert_raises(Fopost::Error) do
      client(max_retries: 1).accounts.platform_metrics('acc_1')
    end

    assert_equal 503, error.status
    assert_equal 'platform_metrics_unavailable', error.code
  end
end
