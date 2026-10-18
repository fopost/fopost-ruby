# frozen_string_literal: true

require 'test_helper'

class AdsTrackingTest < Minitest::Test
  include ClientHelpers

  SCOPE = { workspace_id: 'ws_1', connection_id: 'conn_1', ad_account_id: 'act_123' }.freeze

  UPLOAD_RESULT = {
    'id' => 'batch_1', 'accepted' => 2, 'eventCount' => 2, 'replayed' => false
  }.freeze

  PIXEL_FIXTURE = {
    'id' => 'px_1', 'name' => 'Site', 'code' => '<script>fbq()</script>',
    'createdAt' => '2026-09-01T00:00:00.000Z', 'lastFiredAt' => nil,
    'isUnavailable' => false, 'dataUseSetting' => 'advertising_and_analytics'
  }.freeze

  CUSTOM_CONVERSION_FIXTURE = {
    'id' => 'cc_1', 'name' => 'Checkout', 'pixelId' => 'px_1', 'eventType' => 'PURCHASE',
    'rule' => { 'eventName' => 'PageView', 'urlContains' => '/thank-you' },
    'description' => nil, 'defaultValueMinor' => 1999, 'isArchived' => false, 'isUnavailable' => false,
    'createdAt' => '2026-09-02T00:00:00.000Z', 'lastFiredAt' => nil
  }.freeze

  def test_send_conversions_carries_the_idempotency_key_header
    transport.stub(:post, '/ads/conversions/events', status: 202, json: { 'data' => UPLOAD_RESULT })

    result = client.ads.send_conversions(
      **SCOPE, pixel_id: 'px_1', idempotency_key: 'order-77',
               events: [{ event_name: 'Purchase', occurred_at: '2026-09-18T10:04:00Z', action_source: 'website',
                          email: 'buyer@yourbrand.com', value_minor: 1999, currency: 'USD', content_ids: %w[sku_1] }]
    )

    assert_equal 'order-77', transport.last.headers['Idempotency-Key']
    assert_equal 'Purchase', transport.last.json['events'][0]['eventName']
    assert_equal 'website', transport.last.json['events'][0]['actionSource']
    assert_equal %w[sku_1], transport.last.json['events'][0]['contentIds']
    assert_equal 'batch_1', result.id
    assert_equal 2, result.accepted
    refute result.replayed
  end

  def test_upload_conversions_sends_no_header_without_a_key
    transport.stub(:post, '/ads/conversions', status: 202, json: { 'data' => UPLOAD_RESULT })

    result = client.ads.upload_conversions(
      **SCOPE, pixel_id: 'px_1', events: [{ 'eventName' => 'Lead', 'occurredAt' => '2026-09-18T10:04:00Z' }]
    )

    refute transport.last.headers.key?('Idempotency-Key')
    assert_equal 2, result['accepted']
    assert_equal 2, result.event_count
  end

  def test_conversion_batches_parse_hashed_events
    transport.stub(:get, '/ads/conversions/events',
                   json: { 'data' => [{ 'id' => 'batch_1', 'pixelId' => 'px_1', 'idempotencyKey' => 'order-77',
                                        'eventCount' => 1, 'accepted' => 1,
                                        'events' => [{ 'eventName' => 'Purchase', 'actionSource' => 'website',
                                                       'emailHash' => 'ab12', 'valueMinor' => 1999 }],
                                        'createdAt' => '2026-09-18T10:05:00.000Z' }] })

    batches = client.ads.conversion_batches(workspace_id: 'ws_1', connection_id: 'conn_1', limit: 10)

    assert_equal '10', transport.last.query['limit']
    assert_equal 'order-77', batches[0].idempotency_key
    assert_equal 'ab12', batches[0].events[0].email_hash
    assert_equal Time.utc(2026, 9, 18, 10, 5), batches[0].created_at
  end

  def test_pixel_reads_and_writes
    transport
      .stub(:get, '/ads/pixels', json: { 'data' => [{ 'id' => 'px_1', 'name' => 'Site' }] })
      .stub(:get, '/ads/pixels/px_1', json: { 'data' => PIXEL_FIXTURE })
      .stub(:post, '/ads/pixels', status: 201, json: { 'data' => PIXEL_FIXTURE })
      .stub(:patch, '/ads/pixels/px_1', json: { 'data' => PIXEL_FIXTURE.merge('dataUseSetting' => 'analytics_only') })
      .stub(:post, '/ads/pixels/px_1/share', status: 204)
      .stub(:get, '/ads/pixels/px_1/stats',
            json: { 'data' => { 'since' => '2026-08-21', 'until' => '2026-09-18',
                                'events' => [{ 'eventName' => 'PageView', 'count' => 412 }] } })
      .stub(:get, '/ads/pixels/px_1/match-quality',
            json: { 'data' => [{ 'eventName' => 'Purchase', 'score' => 6.4,
                                 'matchKeys' => [{ 'identifier' => 'email', 'coveragePercent' => 80 }] }] })

    assert_equal 'px_1', client.ads.pixels(**SCOPE)[0].id
    assert_equal 'act_123', transport.last.query['ad_account_id']

    pixel = client.ads.get_pixel('px_1', **SCOPE)

    assert_equal '<script>fbq()</script>', pixel.code
    assert_equal Time.utc(2026, 9, 1), pixel.created_at
    refute pixel.is_unavailable

    assert_equal 'Site', client.ads.create_pixel(**SCOPE, name: 'Site').name
    assert_equal 'Site', transport.last.json['name']

    updated = client.ads.update_pixel('px_1', **SCOPE, data_use_setting: 'analytics_only')

    assert_equal 'analytics_only', updated.data_use_setting
    assert_equal({ 'workspaceId' => 'ws_1', 'connectionId' => 'conn_1', 'adAccountId' => 'act_123',
                   'dataUseSetting' => 'analytics_only' }, transport.last.json)

    assert_nil client.ads.share_pixel('px_1', **SCOPE, target_ad_account_id: 'act_456')
    assert_equal 'act_456', transport.last.json['targetAdAccountId']

    stats = client.ads.pixel_stats('px_1', **SCOPE)

    assert_equal 412, stats.events[0].count

    quality = client.ads.pixel_match_quality('px_1', **SCOPE)

    assert_in_delta 6.4, quality[0].score
    assert_equal 80, quality[0].match_keys[0].coverage_percent
  end

  def test_custom_conversion_create_and_the_rest
    transport
      .stub(:post, '/ads/custom-conversions', status: 201, json: { 'data' => CUSTOM_CONVERSION_FIXTURE })
      .stub(:get, '/ads/custom-conversions', json: { 'data' => [CUSTOM_CONVERSION_FIXTURE] })
      .stub(:get, '/ads/custom-conversions/cc_1', json: { 'data' => CUSTOM_CONVERSION_FIXTURE })
      .stub(:patch, '/ads/custom-conversions/cc_1',
            json: { 'data' => CUSTOM_CONVERSION_FIXTURE.merge('name' => 'Checkout done') })
      .stub(:delete, '/ads/custom-conversions/cc_1', status: 204)

    created = client.ads.create_custom_conversion(
      **SCOPE, pixel_id: 'px_1', name: 'Checkout', event_type: 'PURCHASE',
               rule: { event_name: 'PageView', url_contains: '/thank-you' }, default_value_minor: 1999
    )

    assert_equal 'cc_1', created.id
    assert_equal '/thank-you', created.rule.url_contains
    assert_equal 1999, created.default_value_minor
    assert_equal({ 'eventName' => 'PageView', 'urlContains' => '/thank-you' }, transport.last.json['rule'])
    assert_equal 'PURCHASE', transport.last.json['eventType']
    refute transport.last.json.key?('description')

    assert_equal 'Checkout', client.ads.custom_conversions(**SCOPE)[0].name
    assert_equal 'PURCHASE', client.ads.get_custom_conversion('cc_1', **SCOPE).event_type

    assert_equal 'Checkout done', client.ads.update_custom_conversion('cc_1', **SCOPE, name: 'Checkout done').name
    assert_equal({ 'workspaceId' => 'ws_1', 'connectionId' => 'conn_1', 'adAccountId' => 'act_123',
                   'name' => 'Checkout done' }, transport.last.json)

    assert_nil client.ads.delete_custom_conversion('cc_1', **SCOPE)
    # The scope travels in the body, because the path already carries the id.
    assert_equal 'act_123', transport.last.json['adAccountId']
  end
end
