# frozen_string_literal: true

require 'test_helper'

class AccountGroupsTest < Minitest::Test
  include ClientHelpers

  GROUP = {
    'id' => 'grp_1',
    'name' => 'Launch',
    'account_ids' => %w[acc_1 acc_2],
    'created_at' => '2026-09-01T10:00:00.000Z',
    'updated_at' => '2026-09-01T10:00:00.000Z'
  }.freeze

  def test_list_is_scoped_to_a_workspace
    transport.stub(:get, '/account-groups', json: { 'data' => [GROUP] })

    groups = client.account_groups.list(workspace_id: 'ws_1')

    assert_equal 'grp_1', groups[0].id
    assert_equal %w[acc_1 acc_2], groups[0].account_ids
    assert_equal Time.utc(2026, 9, 1, 10, 0, 0), groups[0].created_at
    assert_equal({ 'workspace_id' => 'ws_1' }, transport.last.query)
  end

  def test_create_sends_workspace_name_and_members
    transport.stub(:post, '/account-groups', status: 201, json: { 'data' => GROUP })

    group = client.account_groups.create(workspace_id: 'ws_1', name: 'Launch', account_ids: %w[acc_1 acc_2])

    assert_equal 'Launch', group.name
    assert_equal({ 'workspace_id' => 'ws_1', 'name' => 'Launch', 'account_ids' => %w[acc_1 acc_2] },
                 transport.last.json)
  end

  def test_create_without_members_omits_account_ids
    transport.stub(:post, '/account-groups', status: 201, json: { 'data' => GROUP })

    client.account_groups.create(workspace_id: 'ws_1', name: 'Launch')

    assert_equal({ 'workspace_id' => 'ws_1', 'name' => 'Launch' }, transport.last.json)
  end

  def test_get_update_set_members_and_delete
    transport
      .stub(:get, '/account-groups/grp_1', json: { 'data' => GROUP })
      .stub(:patch, '/account-groups/grp_1', json: { 'data' => GROUP.merge('name' => 'Renamed') })
      .stub(:put, '/account-groups/grp_1/members', json: { 'data' => GROUP.merge('account_ids' => ['acc_3']) })
      .stub(:delete, '/account-groups/grp_1', json: { 'message' => 'Account group deleted' })

    assert_equal 'grp_1', client.account_groups.get('grp_1').id

    assert_equal 'Renamed', client.account_groups.update('grp_1', name: 'Renamed').name
    assert_equal({ 'name' => 'Renamed' }, transport.last.json)

    assert_equal ['acc_3'], client.account_groups.set_members('grp_1', ['acc_3']).account_ids
    assert_equal({ 'account_ids' => ['acc_3'] }, transport.last.json)

    assert_nil client.account_groups.delete('grp_1')
    assert_equal 'DELETE', transport.last.method.to_s.upcase
  end
end
