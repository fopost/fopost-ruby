# frozen_string_literal: true

require 'test_helper'

class GoogleAdsTest < Minitest::Test
  include ClientHelpers

  SCOPE = { workspace_id: 'ws_1', connection_id: 'conn_1', customer_id: '1234567890' }.freeze

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
