# frozen_string_literal: true

require 'test_helper'

class CommunitiesTest < Minitest::Test
  include ClientHelpers

  COMMUNITY = {
    'id' => 7, 'account_id' => 'acc_1', 'community_id' => '1234', 'name' => 'Ruby devs',
    'member_count' => 120, 'description' => nil, 'image_url' => nil,
    'last_synced_at' => '2026-10-01T10:00:00.000Z', 'created_at' => '2026-10-01T10:00:00.000Z'
  }.freeze

  def test_list_sync_search_add_and_remove
    transport
      .stub(:get, '/accounts/acc_1/communities', json: { 'data' => [COMMUNITY] })
      .stub(:post, '/accounts/acc_1/communities/sync', json: { 'data' => [COMMUNITY], 'note' => 'partial' })
      .stub(:get, '/accounts/acc_1/communities/search',
            json: { 'data' => [{ 'id' => '1234', 'name' => 'Ruby devs', 'description' => '', 'member_count' => 120 }] })
      .stub(:post, '/accounts/acc_1/communities/manual', json: COMMUNITY)
      .stub(:delete, '/accounts/acc_1/communities/7', status: 204)

    assert_equal '1234', client.accounts.list_communities('acc_1')[0].community_id

    sync = client.accounts.sync_communities('acc_1')

    assert_equal 'POST', transport.last.method
    assert_equal 'partial', sync.note
    assert_equal 120, sync.communities[0].member_count

    found = client.accounts.search_communities('acc_1', q: 'ruby')

    assert_equal({ 'q' => 'ruby' }, transport.last.query)
    assert_equal 'Ruby devs', found[0].name

    added = client.accounts.add_community('acc_1', community_id: '1234', name: 'Ruby devs')

    assert_equal({ 'communityId' => '1234', 'name' => 'Ruby devs' }, transport.last.json)
    assert_equal 7, added.id

    assert_nil client.accounts.remove_community('acc_1', 7)
    assert_equal 'DELETE', transport.last.method
    assert_equal '/v1/accounts/acc_1/communities/7', transport.last.path
  end
end
