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

  def test_discord_channels_and_switch
    channel = { 'id' => 'c2', 'name' => 'launches', 'type' => 0, 'parent_id' => nil,
                'nsfw' => false, 'can_post' => true, 'is_current' => true }
    transport.stub(:get, '/accounts/acc_1/discord/channels', json: { 'data' => [channel] })
    transport.stub(:patch, '/accounts/acc_1/discord/channels/current', json: { 'data' => channel })

    channels = client.accounts.list_discord_channels('acc_1')

    assert_equal 'c2', channels[0].id
    assert channels[0].is_current

    client.accounts.switch_discord_channel('acc_1', 'c2')

    assert_equal({ 'channel_id' => 'c2' }, transport.last.json)
  end

  def test_discord_identity_partial_update
    identity = { 'data' => { 'username' => 'Release Bot', 'avatar_url' => nil } }
    transport.stub(:patch, '/accounts/acc_1/discord/identity', json: identity)

    updated = client.accounts.update_discord_identity('acc_1', username: 'Release Bot')

    assert_equal 'Release Bot', updated.username
    # Omitted keywords stay off the wire, so Discord keeps them.
    assert_equal({ 'username' => 'Release Bot' }, transport.last.json)
  end

  def test_discord_event_round_trip
    event = { 'id' => 'e1', 'name' => 'Launch stream', 'description' => nil, 'channel_id' => nil,
              'location' => 'https://example.com/live', 'start_time' => '2026-10-01T18:00:00.000Z',
              'end_time' => '2026-10-01T19:00:00.000Z', 'status' => 'scheduled', 'user_count' => 0 }
    transport.stub(:post, '/accounts/acc_1/discord/events', json: { 'data' => event })
    transport.stub(:get, '/accounts/acc_1/discord/events', json: { 'data' => [event] })
    transport.stub(:patch, '/accounts/acc_1/discord/events/e1',
                   json: { 'data' => event.merge('status' => 'canceled') })
    transport.stub(:delete, '/accounts/acc_1/discord/events/e1', json: { 'data' => { 'deleted' => true } })

    created = client.accounts.create_discord_event('acc_1', name: 'Launch stream',
                                                            start_time: '2026-10-01T18:00:00.000Z',
                                                            end_time: '2026-10-01T19:00:00.000Z',
                                                            location: 'https://example.com/live')

    assert_equal 'e1', created.id
    assert_equal({ 'name' => 'Launch stream', 'start_time' => '2026-10-01T18:00:00.000Z',
                   'end_time' => '2026-10-01T19:00:00.000Z', 'location' => 'https://example.com/live' },
                 transport.last.json)

    assert_equal ['e1'], client.accounts.list_discord_events('acc_1').map(&:id)

    updated = client.accounts.update_discord_event('acc_1', 'e1', status: 'canceled')

    assert_equal 'canceled', updated.status
    assert_equal({ 'status' => 'canceled' }, transport.last.json)

    assert_nil client.accounts.delete_discord_event('acc_1', 'e1')
  end

  def test_discord_members_roles_and_dm
    member = { 'id' => 'u7', 'username' => 'ada', 'is_bot' => false, 'roles' => ['r1'] }
    transport.stub(:get, '/accounts/acc_1/discord/members', json: { 'data' => [member] })
    transport.stub(:put, '/accounts/acc_1/discord/roles/r1/members/u7', json: { 'data' => { 'assigned' => true } })
    transport.stub(:post, '/accounts/acc_1/discord/dm', json: { 'data' => { 'id' => 'm1', 'channel_id' => 'dm1' } })

    members = client.accounts.list_discord_members('acc_1', query: 'ada')

    assert_equal 'u7', members[0].id
    assert_equal({ 'q' => 'ada' }, transport.last.query)

    assert_nil client.accounts.add_discord_member_role('acc_1', 'r1', 'u7')

    sent = client.accounts.send_discord_dm('acc_1', 'u7', 'hi')

    assert_equal 'dm1', sent.channel_id
    assert_equal({ 'member_id' => 'u7', 'content' => 'hi' }, transport.last.json)
  end

  def test_discord_webhook_connection_raises_with_its_code
    body = { 'error' => 'webhook_connection', 'message' => 'Upgrade it to the bot first' }
    transport.stub(:get, '/accounts/acc_1/discord/channels', status: 409, json: body)

    error = assert_raises(Fopost::Error) { client.accounts.list_discord_channels('acc_1') }

    assert_equal 409, error.status
    assert_equal 'webhook_connection', error.code
  end

  def test_create_pinterest_board_sends_only_what_was_given
    board = { 'id' => 'b1', 'name' => 'Recipes', 'privacy' => 'PUBLIC' }
    transport.stub(:post, '/accounts/acc_1/pinterest/boards', status: 201, json: { 'data' => board })

    created = client.accounts.create_pinterest_board('acc_1', name: 'Recipes')

    assert_equal 'b1', created.id
    assert_equal({ 'name' => 'Recipes' }, transport.last.json)
  end

  def test_youtube_playlists_and_transcript
    playlist = { 'id' => 'PL1', 'title' => 'Tutorials', 'is_default' => true }
    transport.stub(:get, '/accounts/acc_1/youtube/playlists', json: { 'data' => [playlist] })
    transport.stub(:get, '/accounts/acc_1/youtube/captions/cap1',
                   json: { 'data' => { 'caption_id' => 'cap1', 'transcript' => "1\nHello\n" } })

    assert client.accounts.list_youtube_playlists('acc_1')[0].is_default
    assert_includes client.accounts.read_youtube_transcript('acc_1', 'cap1').transcript, 'Hello'
  end

  def test_bluesky_languages_round_trip
    transport.stub(:put, '/accounts/acc_1/bluesky/languages',
                   json: { 'data' => { 'languages' => %w[en pt-BR] } })

    result = client.accounts.set_bluesky_languages('acc_1', %w[en pt-BR])

    assert_equal %w[en pt-BR], result.languages
    assert_equal({ 'languages' => %w[en pt-BR] }, transport.last.json)
  end

  def test_tiktok_creator_info_reports_the_accounts_own_switches
    transport.stub(:get, '/accounts/acc_1/tiktok/creator-info',
                   json: { 'data' => { 'privacy_level_options' => ['PUBLIC_TO_EVERYONE'],
                                       'duet_disabled' => true,
                                       'max_video_post_duration_sec' => 600 } })

    info = client.accounts.get_tiktok_creator_info('acc_1')

    assert info.duet_disabled
    assert_equal 600, info.max_video_post_duration_sec
  end

  def test_tiktok_music_and_place_search_pass_the_query_through
    transport.stub(:get, '/accounts/acc_1/tiktok/music',
                   json: { 'data' => [{ 'id' => 'm1', 'title' => 'Sunrise', 'author' => 'Kite' }] })
    transport.stub(:get, '/accounts/acc_1/tiktok/locations',
                   json: { 'data' => [{ 'id' => 'p1', 'name' => 'Blue Bottle' }] })

    tracks = client.accounts.search_tiktok_music('acc_1', q: 'sunrise', limit: 5)

    assert_equal 'm1', tracks[0].id
    assert_equal({ 'q' => 'sunrise', 'limit' => '5' }, transport.last.query)

    places = client.accounts.search_tiktok_locations('acc_1', q: 'cafe')

    assert_equal 'Blue Bottle', places[0].name
  end

  def test_tiktok_video_lookup_returns_the_address_a_repurpose_run_reads
    transport.stub(:post, '/accounts/acc_1/tiktok/video-download',
                   json: { 'data' => { 'video_id' => '7300000000000000000',
                                       'download_url' => 'https://www.tiktok.com/@a/video/7300000000000000000' } })

    video = client.accounts.lookup_tiktok_video('acc_1', 'https://www.tiktok.com/@a/video/7300000000000000000')

    assert_equal '7300000000000000000', video.video_id
    refute_nil video.download_url
  end

  def test_instagram_and_linkedin_reads
    transport.stub(:get, '/accounts/acc_1/instagram/publishing-limit',
                   json: { 'data' => { 'quota_usage' => 12, 'quota_total' => 50, 'remaining' => 38 } })
    mention = { 'urn' => 'urn:li:organization:2414183', 'name' => 'Devtestco',
                'annotation' => '@[Devtestco](urn:li:organization:2414183)' }
    transport.stub(:get, '/accounts/acc_1/linkedin/mentions', json: { 'data' => [mention] })

    assert_equal 38, client.accounts.get_instagram_publishing_limit('acc_1').remaining
    mentions = client.accounts.search_linkedin_mentions('acc_1', 'devtestco')

    assert_equal '@[Devtestco](urn:li:organization:2414183)', mentions[0].annotation
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
