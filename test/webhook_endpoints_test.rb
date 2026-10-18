# frozen_string_literal: true

require 'test_helper'

class WebhookEndpointsTest < Minitest::Test
  include ClientHelpers

  WEBHOOK = {
    'id' => 'wh_1',
    'workspace_id' => 'ws_1',
    'name' => 'CRM',
    'url' => 'https://yourbrand.com/hooks/fopost',
    'events' => ['post.published'],
    'header_names' => ['X-Token'],
    'active' => true,
    'last_triggered_at' => nil,
    'failure_count' => 0,
    'created_at' => '2026-10-01T10:00:00.000Z'
  }.freeze

  DELIVERY = {
    'id' => 'del_1',
    'webhook_id' => 'wh_1',
    'event' => 'post.published',
    'delivery_key' => 'post.published:post_1',
    'attempt' => 1,
    'status' => 'failed',
    'response_status' => 500,
    'response_snippet' => 'boom',
    'duration_ms' => 120,
    'payload_hash' => 'abc',
    'next_retry_at' => '2026-10-01T10:05:00.000Z',
    'created_at' => '2026-10-01T10:00:00.000Z'
  }.freeze

  def test_list_create_update_and_delete
    transport
      .stub(:get, '/webhooks', json: { 'data' => [WEBHOOK] })
      .stub(:post, '/webhooks', status: 201, json: WEBHOOK.merge('secret' => 'whsec_1'))
      .stub(:put, '/webhooks/wh_1', json: WEBHOOK.merge('active' => false))
      .stub(:delete, '/webhooks/wh_1', status: 204)

    assert_equal 'wh_1', client.webhooks.list[0].id

    webhook = client.webhooks.create(workspace_id: 'ws_1', url: 'https://yourbrand.com/hooks/fopost',
                                     events: ['post.published'], name: 'CRM', headers: { 'X-Token' => 't' })

    assert_equal({ 'workspaceId' => 'ws_1', 'url' => 'https://yourbrand.com/hooks/fopost',
                   'events' => ['post.published'], 'name' => 'CRM', 'headers' => { 'X-Token' => 't' } },
                 transport.last.json)
    assert_equal 'whsec_1', webhook.secret
    assert_equal ['X-Token'], webhook.header_names

    updated = client.webhooks.update('wh_1', active: false, headers: nil)

    assert_equal 'PUT', transport.last.method
    assert_equal({ 'active' => false, 'headers' => nil }, transport.last.json)
    refute updated.active

    assert_nil client.webhooks.delete('wh_1')
    assert_equal 'DELETE', transport.last.method
    assert_equal '/v1/webhooks/wh_1', transport.last.path
  end

  def test_test_deliveries_get_delivery_and_redeliver
    transport
      .stub(:post, '/webhooks/wh_1/test', status: 204)
      .stub(:get, '/webhooks/wh_1/deliveries', json: { 'data' => [DELIVERY] })
      .stub(:get, '/webhooks/wh_1/deliveries/del_1', json: DELIVERY.merge('payload' => { 'event' => 'post.published' }))
      .stub(:post, '/webhooks/wh_1/deliveries/del_1/redeliver', status: 204)

    assert_nil client.webhooks.test('wh_1')
    assert_equal 'POST', transport.last.method

    deliveries = client.webhooks.deliveries('wh_1', status: 'failed', limit: 10)

    assert_equal({ 'status' => 'failed', 'limit' => '10' }, transport.last.query)
    assert_equal 500, deliveries[0].response_status
    assert_equal Time.utc(2026, 10, 1, 10, 5, 0), deliveries[0].next_retry_at

    delivery = client.webhooks.get_delivery('wh_1', 'del_1')

    assert_equal({ 'event' => 'post.published' }, delivery.payload)

    assert_nil client.webhooks.redeliver('wh_1', 'del_1')
    assert_equal '/v1/webhooks/wh_1/deliveries/del_1/redeliver', transport.last.path
  end
end
