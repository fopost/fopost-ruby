# frozen_string_literal: true

require 'test_helper'

class BroadcastsTest < Minitest::Test
  include ClientHelpers

  BROADCAST_FIXTURE = {
    'id' => 'bc_1',
    'name' => 'September check-in',
    'text' => 'New colours just landed.',
    'account_id' => 'acc_1',
    'audience' => { 'platforms' => ['instagram'] },
    'status' => 'sent',
    'scheduled_at' => nil,
    'sent_at' => '2026-09-19T10:04:00.000Z',
    'created_at' => '2026-09-19T09:58:00.000Z',
    'counts' => { 'total' => 3, 'sent' => 2, 'skipped' => 1, 'failed' => 0, 'pending' => 0 }
  }.freeze

  SEQUENCE_FIXTURE = {
    'id' => 'seq_1',
    'name' => 'Welcome',
    'account_id' => 'acc_1',
    'steps' => [
      { 'delay_hours' => 0, 'text' => 'Thanks for the follow' },
      { 'delay_hours' => 48, 'text' => 'Here is what people ask first' }
    ],
    'status' => 'active',
    'created_at' => '2026-09-12T08:00:00.000Z',
    'enrollments' => { 'total' => 4, 'active' => 1, 'completed' => 3, 'stopped' => 0, 'failed' => 0 }
  }.freeze

  def test_list_reads_the_pagination_block_not_meta
    transport.stub(:get, '/broadcasts', json: {
                     'data' => [BROADCAST_FIXTURE],
                     'pagination' => { 'page' => 2, 'per_page' => 10, 'total' => 11 }
                   })

    page = client.broadcasts.list(workspace_id: 'ws_1', status: 'sent', page: 2, per_page: 10)

    assert_equal '/v1/broadcasts', transport.last.path
    assert_equal({ 'workspace_id' => 'ws_1', 'status' => 'sent', 'page' => '2', 'per_page' => '10' },
                 transport.last.query)
    assert_equal 1, page.size
    assert_equal 'September check-in', page[0].name
    assert_equal 2, page[0].counts.sent
    assert_equal 1, page[0].counts.skipped
    assert_equal 11, page.meta.total
  end

  def test_create_sends_the_snake_case_body
    transport.stub(:post, '/broadcasts', status: 201, json: { 'data' => BROADCAST_FIXTURE })

    client.broadcasts.create(
      workspace_id: 'ws_1',
      account_id: 'acc_1',
      name: 'September check-in',
      text: 'New colours just landed.',
      audience: { 'platforms' => ['instagram'] },
      scheduled_at: '2026-10-01T09:00:00.000Z'
    )

    body = transport.last.json

    assert_equal 'ws_1', body['workspace_id']
    assert_equal 'acc_1', body['account_id']
    assert_equal '2026-10-01T09:00:00.000Z', body['scheduled_at']
    assert_equal({ 'platforms' => ['instagram'] }, body['audience'])
  end

  # A closed messaging window has to be readable, or a non-send is a mystery.
  def test_a_skipped_recipient_keeps_its_reason
    transport.stub(:get, '/broadcasts/bc_1/recipients', json: {
                     'data' => [{
                       'contact_id' => 'con_1',
                       'display_name' => 'Sam Rivera',
                       'status' => 'skipped',
                       'skip_reason' => 'window_closed',
                       'sent_at' => nil,
                       'error' => nil
                     }],
                     'pagination' => { 'page' => 1, 'per_page' => 50, 'total' => 1 }
                   })

    page = client.broadcasts.recipients('bc_1', status: 'skipped')

    assert_equal 'skipped', transport.last.query['status']
    assert_equal 'skipped', page[0].status
    assert_equal 'window_closed', page[0].skip_reason
  end

  def test_send_and_cancel_post_to_their_own_paths
    transport.stub(:post, '/broadcasts/bc_1/send',
                   json: { 'data' => { 'id' => 'bc_1', 'status' => 'sending', 'recipients' => 3 } })
    result = client.broadcasts.send('bc_1')

    assert_equal '/v1/broadcasts/bc_1/send', transport.last.path
    assert_equal 3, result['recipients']

    transport.stub(:post, '/broadcasts/bc_1/cancel',
                   json: { 'data' => { 'id' => 'bc_1', 'status' => 'cancelled' } })
    cancelled = client.broadcasts.cancel('bc_1')

    assert_equal '/v1/broadcasts/bc_1/cancel', transport.last.path
    assert_equal 'cancelled', cancelled['status']
  end

  def test_sequence_steps_travel_as_given
    transport.stub(:post, '/sequences', status: 201, json: { 'data' => SEQUENCE_FIXTURE })

    sequence = client.sequences.create(
      workspace_id: 'ws_1',
      account_id: 'acc_1',
      name: 'Welcome',
      steps: [{ 'delay_hours' => 0, 'text' => 'Thanks for the follow' }]
    )

    assert_equal 48, sequence.steps[1].delay_hours
    assert_equal [{ 'delay_hours' => 0, 'text' => 'Thanks for the follow' }], transport.last.json['steps']
  end

  def test_enroll_takes_ids_or_an_audience
    transport.stub(:post, '/sequences/seq_1/enroll', json: { 'data' => { 'id' => 'seq_1', 'enrolled' => 2 } })

    client.sequences.enroll('seq_1', contact_ids: %w[con_1 con_2])

    assert_equal %w[con_1 con_2], transport.last.json['contact_ids']

    transport.stub(:post, '/sequences/seq_1/enroll', json: { 'data' => { 'id' => 'seq_1', 'enrolled' => 5 } })
    client.sequences.enroll('seq_1', audience: { 'platforms' => ['telegram'] })

    assert_equal({ 'platforms' => ['telegram'] }, transport.last.json['audience'])
  end

  def test_unenroll_names_the_contacts_it_stops
    transport.stub(:post, '/sequences/seq_1/unenroll', json: { 'data' => { 'id' => 'seq_1', 'stopped' => 1 } })

    result = client.sequences.unenroll('seq_1', ['con_1'])

    assert_equal '/v1/sequences/seq_1/unenroll', transport.last.path
    assert_equal ['con_1'], transport.last.json['contact_ids']
    assert_equal 1, result['stopped']
  end
end
