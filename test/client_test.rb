# frozen_string_literal: true

require 'test_helper'

class ClientTest < Minitest::Test
  include ClientHelpers

  def test_requires_an_api_key
    ENV.delete('FOPOST_API_KEY')
    error = assert_raises(Fopost::ConfigurationError) { Fopost::Client.new }
    assert_match(/api key is required/, error.message)
  end

  def test_falls_back_to_the_environment
    ENV['FOPOST_API_KEY'] = 'fp_from_env'
    transport.stub(:get, '/workspaces', json: { 'data' => [] })
    Fopost::Client.new(base_url: BASE_URL, transport: transport).workspaces.list

    assert_equal 'fp_from_env', transport.last.headers['X-API-Key']
  ensure
    ENV.delete('FOPOST_API_KEY')
  end

  def test_sends_auth_and_agent_headers
    transport.stub(:get, '/workspaces', json: { 'data' => [] })
    client.workspaces.list

    headers = transport.last.headers

    assert_equal API_KEY, headers['X-API-Key']
    assert_equal 'application/json', headers['Accept']
    assert_match(%r{\Afopost-ruby/\d+\.\d+\.\d+\z}, headers['User-Agent'])
  end

  def test_trailing_slash_is_trimmed_from_the_base_url
    assert_equal 'https://example.test/api/v1',
                 Fopost::Client.new(api_key: 'k', base_url: 'https://example.test/api/v1/').base_url
  end

  def test_request_reaches_an_unwrapped_endpoint
    transport.stub(:post, '/analytics/collect', json: { 'queued' => true })

    assert_equal({ 'queued' => true }, client.request(:post, '/analytics/collect', json: { 'scope' => 'all' }))
    assert_equal({ 'scope' => 'all' }, transport.last.json)
  end

  def test_fopost_new_builds_a_client
    assert_instance_of Fopost::Client, Fopost.new(api_key: 'k')
  end

  def test_max_retries_must_be_at_least_one
    assert_raises(Fopost::ConfigurationError) { Fopost::Client.new(api_key: 'k', max_retries: 0) }
  end
end
