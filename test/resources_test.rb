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
