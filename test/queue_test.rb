# frozen_string_literal: true

require 'test_helper'

class QueueTest < Minitest::Test
  include ClientHelpers

  SLOT = {
    'id' => 'slot_1',
    'workspace_id' => 'ws_1',
    'account_id' => nil,
    'weekday' => 1,
    'time' => '09:00',
    'timezone' => 'Europe/Zagreb',
    'created_at' => '2026-10-01T10:00:00.000Z'
  }.freeze

  def test_slots_lists_the_workspace
    transport.stub(:get, '/queue/slots', json: { 'data' => [SLOT] })

    slots = client.queue.slots(workspace_id: 'ws_1')

    assert_equal({ 'workspace_id' => 'ws_1' }, transport.last.query)
    assert_equal 'slot_1', slots[0].id
    assert_equal 1, slots[0].weekday
    assert_nil slots[0].account_id
  end

  def test_create_slot_sends_the_slot
    transport.stub(:post, '/queue/slots', status: 201, json: SLOT.merge('account_id' => 'acc_1'))

    slot = client.queue.create_slot(workspace_id: 'ws_1', weekday: 1, time: '09:00', timezone: 'Europe/Zagreb',
                                    account_id: 'acc_1')

    assert_equal 'POST', transport.last.method
    assert_equal({ 'workspace_id' => 'ws_1', 'weekday' => 1, 'time' => '09:00', 'timezone' => 'Europe/Zagreb',
                   'account_id' => 'acc_1' }, transport.last.json)
    assert_equal 'acc_1', slot.account_id
  end

  def test_update_and_delete_report_moved_posts
    moved = [{ 'id' => 'post_1', 'from' => '2026-10-05T09:00:00.000Z', 'to' => '2026-10-05T10:00:00.000Z' }]
    transport
      .stub(:put, '/queue/slots/slot_1', json: SLOT.merge('time' => '10:00', 'moved' => moved))
      .stub(:delete, '/queue/slots/slot_1', json: { 'deleted' => true, 'moved' => moved })

    updated = client.queue.update_slot('slot_1', time: '10:00')

    assert_equal({ 'time' => '10:00' }, transport.last.json)
    assert_equal '10:00', updated.time
    assert_equal Time.utc(2026, 10, 5, 10, 0, 0), updated.moved.first.to

    deleted = client.queue.delete_slot('slot_1')

    assert_equal 'DELETE', transport.last.method
    assert deleted.deleted
    assert_equal 'post_1', deleted.moved.first.id
  end

  def test_next_and_preview_answer_times
    transport
      .stub(:get, '/queue/next', json: { 'next' => '2026-10-05T09:00:00.000Z' })
      .stub(:get, '/queue/preview', json: { 'data' => ['2026-10-05T09:00:00.000Z', '2026-10-06T09:00:00.000Z'] })

    assert_equal Time.utc(2026, 10, 5, 9, 0, 0), client.queue.next(workspace_id: 'ws_1', account_id: 'acc_1')
    assert_equal({ 'workspace_id' => 'ws_1', 'account_id' => 'acc_1' }, transport.last.query)

    preview = client.queue.preview(workspace_id: 'ws_1', count: 2)

    assert_equal({ 'workspace_id' => 'ws_1', 'count' => '2' }, transport.last.query)
    assert_equal [Time.utc(2026, 10, 5, 9, 0, 0), Time.utc(2026, 10, 6, 9, 0, 0)], preview
  end

  def test_next_is_nil_without_slots
    transport.stub(:get, '/queue/next', json: { 'next' => nil })

    assert_nil client.queue.next(workspace_id: 'ws_1')
  end

  def test_posts_create_and_update_take_schedule_queue
    transport
      .stub(:post, '/posts', status: 201, json: POST_FIXTURE.merge('schedule_mode' => 'queue'))
      .stub(:put, '/posts/post_1', json: POST_FIXTURE)

    client.posts.create(workspace_id: 'ws_1', content: 'Hi', accounts: ['acc_1'], status: 'scheduled',
                        schedule: 'queue')

    assert_equal 'queue', transport.last.json['schedule']
    refute transport.last.json.key?('schedule_at')

    client.posts.update('post_1', schedule: 'queue')

    assert_equal({ 'schedule' => 'queue' }, transport.last.json)
  end
end
