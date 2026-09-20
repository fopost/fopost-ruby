# frozen_string_literal: true

require 'test_helper'

class AdsNetworksTest < Minitest::Test
  include ClientHelpers

  def test_authorize_reaches_whichever_network_the_registry_named
    transport.stub(:post, '/ads/connections/linkedin/authorize',
                   json: { 'data' => { 'url' => 'https://www.linkedin.com/oauth?x=1' } })

    url = client.ads.authorize('linkedin', workspace_id: 'ws_1', return_to: '/ads')

    assert_equal 'https://www.linkedin.com/oauth?x=1', url
    assert_equal({ 'workspaceId' => 'ws_1', 'returnTo' => '/ads' }, transport.last.json)
  end

  def test_providers_carry_what_each_network_supports
    transport.stub(:get, '/ads/providers', json: { 'data' => [{
                     'id' => 'linkedin',
                     'name' => 'LinkedIn Ads',
                     'configured' => false,
                     'capabilities' => { 'conversions' => true },
                     'targetingFacets' => %w[country job_title]
                   }] })

    providers = client.ads.providers

    assert_equal 'linkedin', providers[0].id
    refute providers[0].configured
    assert_equal %w[country job_title], providers[0].targeting_facets
  end

  def test_company_rows_travel_with_the_request
    transport.stub(:post, '/ads/audiences/urn:li:adSegment:44/companies', json: { 'data' => { 'added' => 2 } })

    added = client.ads.add_audience_companies(
      'urn:li:adSegment:44', workspace_id: 'ws_1', connection_id: 'conn_1',
                             companies: [{ 'domain' => 'northwind.example' }, { 'name' => 'Contoso' }]
    )

    assert_equal 2, added
    assert_equal({ 'companies' => [{ 'domain' => 'northwind.example' }, { 'name' => 'Contoso' }] },
                 transport.last.json)
  end

  def test_conversion_events_send_the_identity_the_api_hashes
    transport.stub(:post, '/ads/linkedin/conversion-rules/urn:li:conversion:9/events',
                   json: { 'data' => { 'accepted' => 1 } })

    accepted = client.ads.send_conversion_events(
      'urn:li:conversion:9', workspace_id: 'ws_1', connection_id: 'conn_1',
                             events: [{ 'happenedAt' => 1_758_326_400_000, 'email' => 'buyer@example.test' }]
    )

    assert_equal 1, accepted
    assert_equal({ 'workspace_id' => 'ws_1', 'connection_id' => 'conn_1' }, transport.last.query)
  end
end
