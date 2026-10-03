# frozen_string_literal: true

require 'test_helper'

class ActivityTest < Minitest::Test
  include ClientHelpers

  SECURITY_EVENT = {
    'id' => 'evt_1',
    'workspace_id' => 'ws_1',
    'kind' => 'security',
    'ref_type' => 'member_removed',
    'ref_id' => 'usr_2',
    'summary' => 'Removed sam@example.com',
    'actor' => { 'type' => 'user', 'name' => 'Ada' },
    'time' => '2026-09-20T10:00:00Z'
  }.freeze

  def test_reads_the_audit_log_and_keeps_the_cursor
    transport.stub(:get, '/activity',
                   json: { 'data' => [SECURITY_EVENT], 'meta' => { 'next_cursor' => '42' } })

    page = client.activity.list(workspace_id: 'ws_1', kind: 'security', limit: 1)

    query = transport.calls.last.query

    assert_equal 'security', query['kind']
    assert_equal 'ws_1', query['workspace_id']
    assert_equal 'member_removed', page.events[0].ref_type
    assert_equal 'Ada', page.events[0].actor.name
    assert_equal '42', page.next_cursor
  end

  def test_the_end_of_the_list_is_a_nil_cursor
    transport.stub(:get, '/activity', json: { 'data' => [], 'meta' => { 'next_cursor' => nil } })

    page = client.activity.list

    assert_empty page.events
    assert_nil page.next_cursor
  end
end
