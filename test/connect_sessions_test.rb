# frozen_string_literal: true

require 'test_helper'

class ConnectSessionsTest < Minitest::Test
  include ClientHelpers

  SESSION = {
    'id' => 'cs_1',
    'status' => 'pending',
    'external_user_id' => 'user-42',
    'platforms' => %w[twitter linkedin],
    'redirect_url' => 'https://yourbrand.com/connected',
    'branding' => { 'name' => 'Your Brand', 'logo_url' => 'https://yourbrand.com/logo.png' },
    'account_id' => nil,
    'url' => 'https://app.fopost.com/connect/cs_1',
    'expires_at' => '2026-10-19T10:00:00.000Z',
    'used_at' => nil,
    'created_at' => '2026-10-18T10:00:00.000Z'
  }.freeze

  def test_create_sends_the_camel_case_body_and_reads_the_link
    transport.stub(:post, '/connect-sessions', status: 201, json: { 'data' => SESSION })

    session = client.connect_sessions.create(
      workspace_id: 'ws_1',
      external_user_id: 'user-42',
      platforms: %w[twitter linkedin],
      redirect_url: 'https://yourbrand.com/connected',
      branding: { name: 'Your Brand', logo_url: 'https://yourbrand.com/logo.png' }
    )

    assert_equal 'POST', transport.last.method
    assert_equal '/v1/connect-sessions', transport.last.path
    assert_equal({
                   'externalUserId' => 'user-42',
                   'platforms' => %w[twitter linkedin],
                   'workspaceId' => 'ws_1',
                   'redirectUrl' => 'https://yourbrand.com/connected',
                   'branding' => { 'name' => 'Your Brand', 'logoUrl' => 'https://yourbrand.com/logo.png' }
                 }, transport.last.json)
    assert_equal 'https://app.fopost.com/connect/cs_1', session.url
    assert_equal 'pending', session.status
    assert_equal 'Your Brand', session.branding.name
    assert_equal Time.utc(2026, 10, 19, 10, 0, 0), session.expires_at
  end

  def test_get_reads_a_used_session
    transport.stub(:get, '/connect-sessions/cs_1', json: SESSION.merge('status' => 'used', 'account_id' => 'acc_9'))

    session = client.connect_sessions.get('cs_1')

    assert_equal 'GET', transport.last.method
    assert_equal 'used', session.status
    assert_equal 'acc_9', session.account_id
  end
end
