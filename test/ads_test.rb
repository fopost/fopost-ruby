# frozen_string_literal: true

require 'test_helper'

class AdsTest < Minitest::Test
  include ClientHelpers

  AD_FIXTURE = {
    'id' => 'ad_1',
    'workspaceId' => 'ws_1',
    'kind' => 'boost',
    'name' => 'Launch boost',
    'goal' => 'engagement',
    'status' => 'paused',
    'effectiveStatus' => 'PAUSED',
    'connectionId' => 'conn_1',
    'adAccountId' => 'act_123',
    'sourcePostId' => 'post_1',
    'budgetMinor' => 5000,
    'budgetType' => 'daily',
    'currency' => 'USD',
    'targeting' => { 'countries' => ['US'] },
    'insights' => { 'impressions' => 120, 'reach' => 100, 'clicks' => 9, 'spendMinor' => 450 },
    'insightsAt' => '2026-09-18T10:00:00.000Z',
    'createdAt' => '2026-09-17T10:00:00.000Z'
  }.freeze

  def test_list_parses_ads_and_insights
    transport.stub(:get, '/ads', json: { 'data' => [AD_FIXTURE] })

    ads = client.ads.list(workspace_id: 'ws_1')

    assert_equal({ 'workspace_id' => 'ws_1' }, transport.last.query)
    assert_equal 'ad_1', ads[0].id
    assert_equal 5000, ads[0].budget_minor
    assert_equal 450, ads[0].insights.spend_minor
    assert_equal 'US', ads[0].targeting['countries'][0]
    assert_equal Time.utc(2026, 9, 18, 10), ads[0].insights_at
  end

  def test_read_only_lists
    transport
      .stub(:get, '/ads/external', json: { 'data' => [{ 'id' => 'x_1', 'name' => 'Elsewhere',
                                                        'campaignName' => 'Spring', 'budgetMinor' => 100 }] })
      .stub(:get, '/ads/boostable', json: { 'data' => [{ 'id' => 'post_1', 'text' => 'Hello',
                                                         'deliveries' => [{ 'accountId' => 'acc_1' }] }] })
      .stub(:get, '/ads/connections', json: { 'data' => [{ 'id' => 'conn_1', 'name' => 'Your Brand',
                                                           'authType' => 'business',
                                                           'createdAt' => '2026-09-01T00:00:00.000Z' }] })
      .stub(:get, '/ads/sources', json: { 'data' => [{ 'connectionId' => 'conn_1', 'name' => 'Your Brand',
                                                       'adAccounts' => [{ 'id' => 'act_123' }],
                                                       'pages' => [{ 'id' => '42' }] }] })

    assert_equal 'Spring', client.ads.external(workspace_id: 'ws_1')[0].campaign_name
    assert_equal 'acc_1', client.ads.boostable(workspace_id: 'ws_1')[0].deliveries[0]['accountId']
    assert_equal Time.utc(2026, 9, 1), client.ads.connections(workspace_id: 'ws_1')[0].created_at
    assert_equal 'act_123', client.ads.sources(workspace_id: 'ws_1')[0].ad_accounts[0]['id']
  end

  def test_authorize_meta_returns_the_url
    transport.stub(:post, '/ads/connections/meta/authorize',
                   json: { 'data' => { 'url' => 'https://www.facebook.com/dialog/oauth?x=1' } })

    url = client.ads.authorize_meta(workspace_id: 'ws_1', return_to: '/ads')

    assert_equal 'https://www.facebook.com/dialog/oauth?x=1', url
    assert_equal({ 'workspaceId' => 'ws_1', 'returnTo' => '/ads' }, transport.last.json)
  end

  def test_delete_connection_sends_the_workspace_in_the_query
    transport.stub(:delete, '/ads/connections/conn_1', json: { 'message' => 'Deleted' })

    assert_nil client.ads.delete_connection('conn_1', workspace_id: 'ws_1')
    assert_equal 'DELETE', transport.last.method
    assert_equal({ 'workspace_id' => 'ws_1' }, transport.last.query)
    assert_nil transport.last.body
  end

  def test_boost_sends_camel_case_and_parses_the_ad
    transport.stub(:post, '/ads/boost', status: 201, json: { 'data' => AD_FIXTURE })

    ad = client.ads.boost(
      workspace_id: 'ws_1', connection_id: 'conn_1', ad_account_id: 'act_123', post_id: 'post_1',
      account_id: 'acc_1', name: 'Launch boost', goal: 'engagement',
      budget: { minor: 5000, type: 'daily' }, targeting: { countries: ['US'] }
    )

    assert_equal '/v1/ads/boost', transport.last.path
    assert_equal(
      { 'workspaceId' => 'ws_1', 'connectionId' => 'conn_1', 'adAccountId' => 'act_123', 'postId' => 'post_1',
        'accountId' => 'acc_1', 'name' => 'Launch boost', 'goal' => 'engagement',
        'budget' => { 'minor' => 5000, 'type' => 'daily' }, 'targeting' => { 'countries' => ['US'] } },
      transport.last.json
    )
    assert_equal 'paused', ad.status
    assert_equal 'boost', ad.kind
  end

  def test_create_sends_only_the_creative_fields_given
    transport.stub(:post, '/ads', status: 201, json: { 'data' => AD_FIXTURE.merge('kind' => 'ad') })

    ad = client.ads.create(
      workspace_id: 'ws_1', connection_id: 'conn_1', ad_account_id: 'act_123', page_id: '42',
      name: 'Standalone', goal: 'traffic', budget: { 'minor' => 5000, 'type' => 'daily' },
      targeting: { 'countries' => ['US'] }, text: 'See what is new', destination_url: 'https://yourbrand.com',
      paused: false
    )

    body = transport.last.json

    assert_equal '42', body['pageId']
    assert_equal 'https://yourbrand.com', body['destinationUrl']
    refute body['paused']
    refute body.key?('headline')
    refute body.key?('mediaUrl')
    assert_equal 'ad', ad.kind
  end

  def test_refresh_set_status_and_delete_carry_the_workspace_query
    transport
      .stub(:post, '/ads/ad_1/refresh', json: { 'data' => AD_FIXTURE })
      .stub(:patch, '/ads/ad_1', json: { 'data' => AD_FIXTURE.merge('status' => 'active') })
      .stub(:delete, '/ads/ad_1', json: { 'message' => 'Deleted' })

    assert_equal 'ad_1', client.ads.refresh('ad_1', workspace_id: 'ws_1').id
    assert_equal 'POST', transport.last.method
    assert_equal({ 'workspace_id' => 'ws_1' }, transport.last.query)
    assert_nil transport.last.body

    assert_equal 'active', client.ads.set_status('ad_1', workspace_id: 'ws_1', status: 'active').status
    assert_equal 'PATCH', transport.last.method
    assert_equal({ 'status' => 'active' }, transport.last.json)
    assert_equal({ 'workspace_id' => 'ws_1' }, transport.last.query)

    assert_nil client.ads.delete('ad_1', workspace_id: 'ws_1')
    assert_equal 'DELETE', transport.last.method
    assert_equal({ 'workspace_id' => 'ws_1' }, transport.last.query)
  end

  def test_audiences_and_create_audience
    transport
      .stub(:get, '/ads/audiences', json: {
              'data' => { 'audiences' => [{ 'id' => 'aud_1', 'name' => 'Customers', 'subtype' => 'CUSTOM',
                                            'sizeLower' => 1000, 'sizeUpper' => 2000 }],
                          'pixels' => [{ 'id' => 'px_1', 'name' => 'Site' }], 'workspaceId' => 'ws_1' }
            })
      .stub(:post, '/ads/audiences', json: { 'data' => { 'id' => 'aud_2', 'added' => 3 } })

    result = client.ads.audiences(connection_id: 'conn_1', ad_account_id: 'act_123')

    assert_equal({ 'connection_id' => 'conn_1', 'ad_account_id' => 'act_123' }, transport.last.query)
    assert_equal 'CUSTOM', result.audiences[0].subtype
    assert_equal 1000, result.audiences[0].size_lower
    assert_equal 'px_1', result.pixels[0]['id']

    created = client.ads.create_audience(
      workspace_id: 'ws_1', connection_id: 'conn_1', ad_account_id: 'act_123', name: 'Lookalike',
      spec: { subtype: 'LOOKALIKE', originAudienceId: 'aud_1', country: 'US' }
    )

    assert_equal({ 'id' => 'aud_2', 'added' => 3 }, created)
    assert_equal 'LOOKALIKE', transport.last.json['spec']['subtype']
    refute transport.last.json.key?('description')
  end

  def test_search_targeting
    transport.stub(:get, '/ads/targeting/search',
                   json: { 'data' => [{ 'id' => 'US', 'name' => 'United States', 'detail' => 'country' }] })

    options = client.ads.search_targeting(connection_id: 'conn_1', type: 'country', q: 'united')

    assert_equal({ 'connection_id' => 'conn_1', 'type' => 'country', 'q' => 'united' }, transport.last.query)
    assert_equal 'United States', options[0].name
  end

  def test_lead_forms_create_and_leads
    transport
      .stub(:get, '/ads/lead-forms', json: {
              'data' => [{ 'connectionId' => 'conn_1', 'pageId' => '42', 'pageName' => 'Your Brand',
                           'forms' => [{ 'id' => 'form_1', 'name' => 'Newsletter', 'leadsCount' => 12,
                                         'questions' => %w[EMAIL FULL_NAME] }] }]
            })
      .stub(:post, '/ads/lead-forms', json: { 'data' => { 'id' => 'form_2' } })
      .stub(:get, '/ads/lead-forms/form_1/leads', json: {
              'data' => { 'leads' => [{ 'id' => 'lead_1', 'adName' => 'Launch',
                                        'fields' => [{ 'name' => 'full_name', 'values' => ['Jordan Vale'] }],
                                        'isOrganic' => false }],
                          'nextCursor' => 'abc' }
            })

    sources = client.ads.lead_forms(workspace_id: 'ws_1')

    assert_equal 12, sources[0].forms[0].leads_count
    assert_equal %w[EMAIL FULL_NAME], sources[0].forms[0].questions

    id = client.ads.create_lead_form(
      workspace_id: 'ws_1', connection_id: 'conn_1', page_id: '42', name: 'Newsletter', questions: ['EMAIL'],
      privacy_policy_url: 'https://yourbrand.com/privacy', thank_you_message: 'Thanks'
    )

    assert_equal 'form_2', id
    assert_equal(
      { 'workspaceId' => 'ws_1', 'connectionId' => 'conn_1', 'pageId' => '42', 'name' => 'Newsletter',
        'questions' => ['EMAIL'], 'privacyPolicyUrl' => 'https://yourbrand.com/privacy',
        'thankYouMessage' => 'Thanks' },
      transport.last.json
    )

    page = client.ads.leads('form_1', connection_id: 'conn_1', page_id: '42', after: 'cursor_0')

    assert_equal({ 'connection_id' => 'conn_1', 'page_id' => '42', 'after' => 'cursor_0' }, transport.last.query)
    assert_equal 'lead_1', page.leads[0].id
    assert_equal 'abc', page.next_cursor
  end
end
