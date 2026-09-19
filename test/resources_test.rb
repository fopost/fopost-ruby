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

  def test_create_telegram_connect_code_sends_the_workspace
    data = { 'code' => 'abc123', 'command' => '/connect abc123', 'bot_username' => 'fopost_bot',
             'deep_link' => nil, 'group_link' => nil, 'expires_at' => '2026-09-19T12:15:00Z' }
    transport.stub(:post, '/accounts/telegram/connect-code', status: 201, json: { 'data' => data })

    code = client.accounts.create_telegram_connect_code(workspace_id: 'ws_1')

    assert_equal 'abc123', code.code
    assert_equal 'fopost_bot', code.bot_username
    assert_nil code.deep_link
    assert_kind_of Time, code.expires_at
    assert_equal({ 'workspaceId' => 'ws_1' }, transport.last.json)
  end

  def test_get_telegram_connect_status_sends_the_code
    transport.stub(:get, '/accounts/telegram/connect-code/status',
                   json: { 'data' => { 'status' => 'failed', 'account_id' => nil, 'reason' => 'card_required' } })

    status = client.accounts.get_telegram_connect_status('abc123')

    assert_equal 'failed', status.status
    assert_equal 'card_required', status.reason
    assert_equal({ 'code' => 'abc123' }, transport.last.query)
  end

  def test_telegram_bot_commands_get_set_and_delete
    menu = { 'data' => { 'commands' => [{ 'command' => 'start', 'description' => 'Start' }] } }
    transport.stub(:get, '/accounts/acc_1/telegram/commands', json: menu)
    transport.stub(:put, '/accounts/acc_1/telegram/commands', json: menu)
    transport.stub(:delete, '/accounts/acc_1/telegram/commands', json: { 'data' => { 'commands' => [] } })

    assert_equal 'start', client.accounts.get_telegram_bot_commands('acc_1').commands[0].command

    set = client.accounts.set_telegram_bot_commands('acc_1', [{ command: 'start', description: 'Start' }])

    assert_equal 'Start', set.commands[0].description
    assert_equal({ 'commands' => [{ 'command' => 'start', 'description' => 'Start' }] }, transport.last.json)
    assert_empty client.accounts.delete_telegram_bot_commands('acc_1').commands
  end

  def test_slack_channels_and_members
    channel = { 'id' => 'C1', 'name' => 'general', 'is_private' => false, 'is_member' => true, 'is_current' => true }
    member = { 'id' => 'U1', 'name' => 'sam', 'real_name' => 'Sam Rivera', 'display_name' => nil,
               'avatar' => nil, 'is_bot' => false }
    transport.stub(:get, '/accounts/acc_1/slack/channels', json: { 'data' => [channel] })
    transport.stub(:get, '/accounts/acc_1/slack/members', json: { 'data' => [member] })

    channels = client.accounts.list_slack_channels('acc_1')

    assert_equal 'C1', channels[0].id
    assert channels[0].is_current

    members = client.accounts.list_slack_members('acc_1')

    assert_equal 'U1', members[0].id
    assert_nil members[0].display_name
  end

  def test_slack_identity_get_and_partial_update
    identity = { 'data' => { 'username' => 'Launch Bot', 'icon_url' => nil, 'icon_emoji' => ':rocket:' } }
    transport.stub(:get, '/accounts/acc_1/slack/identity', json: identity)
    transport.stub(:patch, '/accounts/acc_1/slack/identity', json: identity)

    assert_equal ':rocket:', client.accounts.get_slack_identity('acc_1').icon_emoji

    updated = client.accounts.update_slack_identity('acc_1', username: 'Launch Bot', icon_url: nil)

    assert_equal 'Launch Bot', updated.username
    # Omitted keywords stay off the wire; nil is sent to clear.
    assert_equal({ 'username' => 'Launch Bot', 'icon_url' => nil }, transport.last.json)
  end

  def test_slack_webhook_connection_raises_with_its_code
    body = { 'error' => 'webhook_connection', 'message' => 'Reconnect' }
    transport.stub(:get, '/accounts/acc_1/slack/channels', status: 409, json: body)

    error = assert_raises(Fopost::Error) { client.accounts.list_slack_channels('acc_1') }

    assert_equal 409, error.status
    assert_equal 'webhook_connection', error.code
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
