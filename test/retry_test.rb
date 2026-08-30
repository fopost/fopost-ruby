# frozen_string_literal: true

require 'test_helper'

class RetryTest < Minitest::Test
  include ClientHelpers

  def test_a_429_is_retried_after_the_interval_the_api_asks_for
    transport
      .stub(:get, '/workspaces', status: 429, headers: { 'retry-after' => '2' }, json: { 'error' => 'rate_limited' })
      .stub(:get, '/workspaces', json: { 'data' => [WORKSPACE_FIXTURE] })

    assert_equal 'ws_1', client.workspaces.list[0].id
    assert_equal [2.0], slept
    assert_equal 2, transport.calls.size
  end

  def test_the_wait_is_capped
    transport
      .stub(:get, '/workspaces', status: 429, headers: { 'retry-after' => '3600' }, json: {})
      .stub(:get, '/workspaces', json: { 'data' => [] })

    client.workspaces.list

    assert_equal [Fopost::HTTP::Client::MAX_RETRY_WAIT], slept
  end

  def test_a_missing_retry_after_waits_a_second
    transport
      .stub(:get, '/workspaces', status: 429, json: {})
      .stub(:get, '/workspaces', json: { 'data' => [] })

    client.workspaces.list

    assert_equal [1.0], slept
  end

  def test_an_http_date_retry_after_is_understood
    transport
      .stub(:get, '/workspaces', status: 429, headers: { 'retry-after' => (Time.now + 5).httpdate }, json: {})
      .stub(:get, '/workspaces', json: { 'data' => [] })

    client.workspaces.list

    assert_in_delta 5.0, slept.first, 1.5
  end

  def test_max_retries_counts_total_attempts
    transport.stub(:get, '/workspaces', status: 429, headers: { 'retry-after' => '1' },
                                        json: { 'error' => 'rate_limited', 'message' => 'Slow down.' })

    error = assert_raises(Fopost::RateLimitError) { client.workspaces.list }

    assert_equal 3, transport.calls.size
    assert_equal 2, slept.size
    assert_in_delta(1.0, error.retry_after)
  end
end
