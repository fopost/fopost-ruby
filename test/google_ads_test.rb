# frozen_string_literal: true

require 'test_helper'

class GoogleAdsTest < Minitest::Test
  include ClientHelpers

  SCOPE = { workspace_id: 'ws_1', connection_id: 'conn_1', customer_id: '1234567890' }.freeze

  KEYWORD_FIXTURE = {
    'id' => '1234567890~keyword~77~99',
    'adGroupId' => '1234567890~adGroup~77',
    'text' => 'running shoes',
    'matchType' => 'EXACT',
    'status' => 'ENABLED',
    'cpcBidMinor' => 180,
    'negative' => false
  }.freeze

  def test_keywords_name_the_connection_and_the_customer
    transport.stub(:get, '/ads/google/keywords', json: { 'data' => [KEYWORD_FIXTURE] })

    keywords = client.ads.google.keywords(
      connection_id: 'conn_1', customer_id: '1234567890', ad_group_id: '1234567890~adGroup~77'
    )

    assert_equal 'running shoes', keywords[0].text
    assert_equal 180, keywords[0].cpc_bid_minor
    query = transport.last.query

    assert_equal 'conn_1', query['connection_id']
    assert_equal '1234567890', query['customer_id']
    assert_equal '1234567890~adGroup~77', query['ad_group_id']
  end

  def test_create_keyword_sends_a_camel_case_body
    transport.stub(:post, '/ads/google/keywords', status: 201,
                                                  json: { 'data' => { 'id' => '1234567890~keyword~77~99' } })

    id = client.ads.google.create_keyword(
      **SCOPE, ad_group_id: '1234567890~adGroup~77', text: 'running shoes', match_type: 'EXACT'
    )

    assert_equal '1234567890~keyword~77~99', id
    body = transport.last.json

    assert_equal '1234567890~adGroup~77', body['adGroupId']
    assert_equal 'EXACT', body['matchType']
    assert_equal '1234567890', body['customerId']
  end

  def test_delete_carries_the_scope_in_the_body
    transport.stub(:delete, '/ads/google/assets/1234567890~asset~4321', status: 204)

    client.ads.google.delete_asset('1234567890~asset~4321', **SCOPE)

    assert_equal(
      { 'workspaceId' => 'ws_1', 'connectionId' => 'conn_1', 'customerId' => '1234567890' },
      transport.last.json
    )
  end

  def test_ad_schedule_is_replaced_with_put
    transport.stub(:put, '/ads/google/ad-schedule', json: { 'data' => { 'slots' => 2 } })

    slots = client.ads.google.set_ad_schedule(
      **SCOPE,
      campaign_id: '1234567890~campaign~55',
      slots: [{ 'dayOfWeek' => 'MONDAY', 'startHour' => 9, 'endHour' => 18 }]
    )

    assert_equal 2, slots
    assert_equal 'PUT', transport.last.method.to_s.upcase
  end

  def test_query_returns_rows_as_google_sends_them
    transport.stub(:post, '/ads/insights/query',
                   json: { 'data' => { 'rows' => [{ 'campaign' => { 'id' => '55' } }] } })

    rows = client.ads.google.query(
      connection_id: 'conn_1', customer_id: '1234567890', query: 'SELECT campaign.id FROM campaign'
    )

    assert_equal [{ 'campaign' => { 'id' => '55' } }], rows
  end

  def test_authorize_google_has_its_own_route
    transport.stub(:post, '/ads/connections/google/authorize',
                   json: { 'data' => { 'url' => 'https://accounts.google.com/o/x' } })

    assert_equal 'https://accounts.google.com/o/x', client.ads.authorize_google(workspace_id: 'ws_1')
  end
end
