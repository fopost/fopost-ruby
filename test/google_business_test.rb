# frozen_string_literal: true

require 'test_helper'

class GoogleBusinessTest < Minitest::Test
  include ClientHelpers

  ROUTES = [
    [:get, '/accounts/acc_1/gbp/location', ->(gb) { gb.get_location('acc_1') }],
    [:patch, '/accounts/acc_1/gbp/location', ->(gb) { gb.update_location('acc_1', title: 'Corner Bakery') }],
    [:get, '/accounts/acc_1/gbp/attributes', ->(gb) { gb.get_attributes('acc_1') }],
    [:patch, '/accounts/acc_1/gbp/attributes', ->(gb) { gb.update_attributes('acc_1', []) }],
    [:get, '/accounts/acc_1/gbp/menus', ->(gb) { gb.get_menus('acc_1') }],
    [:put, '/accounts/acc_1/gbp/menus', ->(gb) { gb.replace_menus('acc_1', []) }],
    [:get, '/accounts/acc_1/gbp/services', ->(gb) { gb.get_services('acc_1') }],
    [:put, '/accounts/acc_1/gbp/services', ->(gb) { gb.replace_services('acc_1', []) }],
    [:get, '/accounts/acc_1/gbp/media', ->(gb) { gb.list_media('acc_1') }],
    [:post, '/accounts/acc_1/gbp/media', ->(gb) { gb.add_media('acc_1', media_id: 'm_1') }],
    [:delete, '/accounts/acc_1/gbp/media/CAoSL', ->(gb) { gb.delete_media('acc_1', 'CAoSL') }],
    [:get, '/accounts/acc_1/gbp/place-actions', ->(gb) { gb.list_place_actions('acc_1') }],
    [:post, '/accounts/acc_1/gbp/place-actions',
     ->(gb) { gb.create_place_action('acc_1', uri: 'https://example.com/b', place_action_type: 'APPOINTMENT') }],
    [:patch, '/accounts/acc_1/gbp/place-actions/links-1',
     ->(gb) { gb.update_place_action('acc_1', 'links-1', is_preferred: true) }],
    [:delete, '/accounts/acc_1/gbp/place-actions/links-1',
     ->(gb) { gb.delete_place_action('acc_1', 'links-1') }],
    [:get, '/accounts/acc_1/gbp/verification', ->(gb) { gb.get_verification_options('acc_1') }],
    [:post, '/accounts/acc_1/gbp/verification/start', ->(gb) { gb.start_verification('acc_1', method: 'SMS') }],
    [:post, '/accounts/acc_1/gbp/verification/complete',
     ->(gb) { gb.complete_verification('acc_1', verification_name: 'v1', pin: '123456') }]
  ].freeze

  def test_every_method_maps_onto_its_route
    ROUTES.each do |verb, path, call|
      transport.stub(verb, path, json: { 'data' => { 'ok' => true } })
      call.call(client.google_business)

      assert_equal verb.to_s.upcase, transport.last.method.to_s.upcase
      assert_equal "#{BASE_PATH}#{path}", transport.last.path
    end
  end

  def test_a_patch_carries_only_the_fields_the_caller_set
    transport.stub(:patch, '/accounts/acc_1/gbp/location', json: { 'data' => {} })
    client.google_business.update_location('acc_1', description: nil, store_code: 'S-12')

    assert_equal({ 'description' => nil, 'store_code' => 'S-12' }, transport.last.json)
  end

  def test_a_photo_is_named_by_its_library_id
    transport.stub(:post, '/accounts/acc_1/gbp/media', json: { 'data' => {} })
    client.google_business.add_media('acc_1', media_id: 'm_1', category: 'INTERIOR')

    assert_equal({ 'media_id' => 'm_1', 'category' => 'INTERIOR' }, transport.last.json)
  end

  def test_performance_repeats_the_metric_parameter
    transport.stub(:get, '/accounts/acc_1/gbp/performance', json: { 'data' => {} })
    client.google_business.get_performance(
      'acc_1', start_date: '2026-09-01', end_date: '2026-09-07',
               daily_metrics: %w[CALL_CLICKS WEBSITE_CLICKS]
    )

    query = URI.decode_www_form(transport.last.uri.query.to_s)
    metrics = query.filter_map { |k, v| v if k == 'daily_metrics' }

    assert_equal %w[CALL_CLICKS WEBSITE_CLICKS], metrics
    assert_equal '2026-09-01', transport.last.query['start_date']
  end

  def test_search_keywords_asks_the_same_route_for_the_monthly_terms
    transport.stub(:get, '/accounts/acc_1/gbp/performance', json: { 'data' => {} })
    client.google_business.get_search_keywords('acc_1', start_date: '2026-08-01', end_date: '2026-09-01')

    assert_equal 'true', transport.last.query['keywords']
  end

  def test_assign_hands_the_location_to_another_workspace
    transport.stub(:post, '/accounts/acc_1/gbp/assign',
                   json: { 'data' => { 'id' => 'acc_1', 'workspace_id' => 'ws_2' } })
    moved = client.google_business.assign('acc_1', workspace_id: 'ws_2')

    assert_equal({ 'workspace_id' => 'ws_2' }, transport.last.json)
    assert_equal 'acc_1', moved.id
  end

  def test_a_pending_api_grant_surfaces_as_unavailable
    transport.stub(:get, '/accounts/acc_1/gbp/location', status: 503,
                                                         json: { 'error' => 'configuration_error',
                                                                 'message' => 'Not available yet' })

    error = assert_raises(Fopost::Error) { client.google_business.get_location('acc_1') }

    assert_equal 503, error.status
    assert_equal 'configuration_error', error.code
  end
end
