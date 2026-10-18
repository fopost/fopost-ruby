# frozen_string_literal: true

require 'test_helper'

class LogsTest < Minitest::Test
  include ClientHelpers

  def test_list_reads_rows_cursor_and_summary
    transport.stub(:get, '/logs', json: {
                     'data' => [{ 'id' => 1, 'workspace_id' => 'ws_1', 'time' => '2026-10-01T10:00:00.000Z',
                                  'auth_method' => 'api_key', 'method' => 'POST', 'route' => '/v1/posts',
                                  'path' => '/v1/posts', 'status_code' => 422, 'duration_ms' => 40,
                                  'platform' => nil, 'message' => 'content required' }],
                     'meta' => { 'next_cursor' => '1', 'has_more' => true },
                     'summary' => { 'since' => '2026-09-24T00:00:00.000Z', 'total' => 10, 'errors' => 1,
                                    'buckets' => [{ 'at' => '2026-10-01T00:00:00.000Z', 'total' => 10,
                                                    'errors' => 1 }] }
                   })

    page = client.logs.list(workspace_id: 'ws_1', status: 'failed', days: 7, limit: 50, before: 99)

    assert_equal 'GET', transport.last.method
    assert_equal({ 'workspace_id' => 'ws_1', 'days' => '7', 'status' => 'failed', 'limit' => '50', 'before' => '99' },
                 transport.last.query)
    assert_equal 422, page.logs[0].status_code
    assert_equal '1', page.next_cursor
    assert page.has_more
    assert_equal 1, page.summary.errors
    assert_equal 10, page.summary.buckets[0].total
  end
end
