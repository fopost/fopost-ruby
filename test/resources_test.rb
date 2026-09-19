# frozen_string_literal: true

require 'test_helper'

class ResourcesTest < Minitest::Test
  include ClientHelpers

  def test_workspaces_list_and_get
    transport
      .stub(:get, '/workspaces', json: { 'data' => [WORKSPACE_FIXTURE] })
      .stub(:get, '/workspaces/ws_1', json: { 'data' => WORKSPACE_FIXTURE })

    workspaces = client.workspaces.list

    assert_equal 1, workspaces.size
    assert_equal 'Acme', workspaces[0].name
    assert_equal 'acc_1', workspaces[0].accounts[0].id

    assert_equal 'ws_1', client.workspaces.get('ws_1').id
  end

  def test_accounts_list_uses_the_camel_case_param
    transport.stub(:get, '/accounts', json: { 'data' => [ACCOUNT_FIXTURE] })

    accounts = client.accounts.list(workspace_id: 'ws_1')

    assert_equal 'ws_1', accounts[0].workspace_id
    assert accounts[0].is_primary
    assert_equal Time.utc(2026, 8, 12, 9, 0, 0), accounts[0].last_health_check
    assert_equal({ 'workspaceId' => 'ws_1' }, transport.last.query)
  end

  def test_accounts_list_omits_an_absent_workspace
    transport.stub(:get, '/accounts', json: { 'data' => [] })

    client.accounts.list

    assert_nil transport.last.uri.query
  end

  def test_account_health_is_a_plain_hash
    transport.stub(:get, '/accounts/acc_1/health', json: { 'data' => { 'status' => 'healthy' } })

    assert_equal({ 'status' => 'healthy' }, client.accounts.health('acc_1'))
  end

  def test_accounts_list_filters_by_group
    transport.stub(:get, '/accounts', json: { 'data' => [ACCOUNT_FIXTURE.merge('platformName' => 'FoPost HQ')] })

    accounts = client.accounts.list(group_id: 'grp_1')

    assert_equal 'FoPost HQ', accounts[0].platform_name
    assert_equal({ 'group_id' => 'grp_1' }, transport.last.query)
  end

  def test_account_update_sends_the_display_name_and_nil_resets_it
    transport.stub(:patch, '/accounts/acc_1',
                   json: { 'data' => { 'id' => 'acc_1', 'name' => 'Brand', 'platform_name' => 'FoPost' } })

    renamed = client.accounts.update('acc_1', display_name: 'Brand')

    assert_equal 'Brand', renamed.name
    assert_equal 'FoPost', renamed.platform_name
    assert_equal({ 'display_name' => 'Brand' }, transport.last.json)

    client.accounts.update('acc_1', display_name: nil)

    assert_equal({ 'display_name' => nil }, transport.last.json)
  end

  def test_account_move_posts_the_target_workspace
    transport.stub(:post, '/accounts/acc_1/move', json: { 'data' => { 'id' => 'acc_1', 'workspace_id' => 'ws_2' } })

    assert_equal 'ws_2', client.accounts.move('acc_1', workspace_id: 'ws_2').workspace_id
    assert_equal({ 'workspace_id' => 'ws_2' }, transport.last.json)
  end

  def test_account_move_conflict_keeps_the_blocking_tables_on_the_error
    transport.stub(:post, '/accounts/acc_1/move', status: 409,
                                                  json: { 'error' => 'move_blocked', 'message' => 'Account has history',
                                                          'blocking_tables' => ['posts'] })

    error = assert_raises(Fopost::Error) { client.accounts.move('acc_1', workspace_id: 'ws_2') }

    assert_equal 409, error.status
    assert_equal 'move_blocked', error.code
    assert_equal ['posts'], error.body['blocking_tables']
  end

  def test_labels_list
    transport.stub(:get, '/labels', json: { 'data' => [LABEL_FIXTURE] })

    labels = client.labels.list(workspace_id: 'ws_1')

    assert_equal 'Launch', labels[0].name
    assert_equal 'ws_1', labels[0].workspace['id']
    assert_equal({ 'workspace_id' => 'ws_1' }, transport.last.query)
  end

  def test_a_list_endpoint_answering_bare_still_parses
    transport.stub(:get, '/workspaces', json: [WORKSPACE_FIXTURE])

    assert_equal 'ws_1', client.workspaces.list[0].id
  end
end
