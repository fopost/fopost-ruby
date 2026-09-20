# frozen_string_literal: true

require 'test_helper'

class ContactsTest < Minitest::Test
  include ClientHelpers

  CONTACT_FIXTURE = {
    'id' => 'con_1',
    'display_name' => 'Ada Okafor',
    'channels' => [
      { 'platform' => 'instagram', 'handle' => 'adaokafor', 'externalId' => '178414' },
      { 'platform' => 'x', 'handle' => 'ada_writes', 'externalId' => nil }
    ],
    'source' => 'inbox',
    'note' => nil,
    'first_seen_at' => '2026-04-02T09:14:00.000Z',
    'last_seen_at' => '2026-09-18T14:30:00.000Z',
    'fields' => { 'plan_tier' => 'Pro' },
    'labels' => [{ 'id' => 'lbl_1', 'name' => 'VIP', 'color' => '#0070f3' }]
  }.freeze

  def test_list_reads_the_pagination_block_not_meta
    transport.stub(:get, '/contacts', json: {
                     'data' => [CONTACT_FIXTURE],
                     'pagination' => { 'page' => 2, 'per_page' => 10, 'total' => 11 }
                   })

    page = client.contacts.list(workspace_id: 'ws_1', search: 'ada', page: 2, per_page: 10)

    assert_equal '/v1/contacts', transport.last.path
    assert_equal({ 'workspace_id' => 'ws_1', 'search' => 'ada', 'page' => '2', 'per_page' => '10' },
                 transport.last.query)
    assert_equal 1, page.size
    assert_equal 'Ada Okafor', page[0].display_name
    assert_equal '178414', page[0].channels[0].external_id
    assert_equal 'Pro', page[0].fields['plan_tier']
    assert_equal 'VIP', page[0].labels[0].name
    assert_equal 11, page.meta.total
    assert_equal 2, page.meta.page
  end

  def test_create_sends_the_wire_names
    transport.stub(:post, '/contacts', json: { 'data' => CONTACT_FIXTURE })

    contact = client.contacts.create(
      workspace_id: 'ws_1',
      channels: [{ 'platform' => 'x', 'handle' => 'ada_writes' }],
      display_name: 'Ada Okafor',
      fields: { 'plan_tier' => 'Pro' }
    )

    assert_equal 'POST', transport.last.method
    assert_equal({
                   'workspace_id' => 'ws_1',
                   'channels' => [{ 'platform' => 'x', 'handle' => 'ada_writes' }],
                   'display_name' => 'Ada Okafor',
                   'fields' => { 'plan_tier' => 'Pro' }
                 }, transport.last.json)
    assert_equal 'con_1', contact.id
  end

  def test_update_sends_only_what_was_passed_and_keeps_a_null_field
    transport.stub(:patch, '/contacts/con_1', json: { 'data' => CONTACT_FIXTURE })

    client.contacts.update('con_1', fields: { 'region' => nil })

    assert_equal 'PATCH', transport.last.method
    assert_equal({ 'fields' => { 'region' => nil } }, transport.last.json)
  end

  def test_conversations_returns_the_threads_a_contact_appears_in
    transport.stub(:get, '/contacts/con_1/conversations', json: {
                     'data' => [{
                       'key' => 't_182736',
                       'account_id' => 'acc_1',
                       'account_username' => 'yourbrand',
                       'platform' => 'instagram',
                       'messages' => 14,
                       'received' => 9,
                       'sent' => 5,
                       'last_message_at' => '2026-09-18T14:30:00.000Z',
                       'last_item_id' => 'inb_1'
                     }]
                   })

    rows = client.contacts.conversations('con_1', limit: 10)

    assert_equal({ 'limit' => '10' }, transport.last.query)
    assert_equal 1, rows.size
    assert_equal 't_182736', rows[0].key
    assert_equal 9, rows[0].received
  end

  def test_import_reports_what_merged_and_what_was_skipped
    transport.stub(:post, '/contacts/import', json: {
                     'data' => {
                       'created' => 1,
                       'merged' => 2,
                       'skipped' => [{ 'row' => 4, 'reason' => 'platform and handle are both required' }],
                       'unknownColumns' => %w[lifetime_value]
                     }
                   })

    result = client.contacts.import(workspace_id: 'ws_1', csv: "platform,handle\nx,ada_writes")

    assert_equal 1, result.created
    assert_equal 2, result.merged
    assert_equal 4, result.skipped[0].row
    assert_equal %w[lifetime_value], result.unknown_columns
  end

  def test_create_field_puts_the_workspace_on_the_query
    transport.stub(:post, '/contacts/fields', json: {
                     'data' => {
                       'id' => 'fld_1', 'key' => 'plan_tier', 'name' => 'Plan Tier',
                       'type' => 'select', 'options' => %w[Free Pro], 'position' => 0
                     }
                   })

    field = client.contacts.create_field(workspace_id: 'ws_1', key: 'plan_tier', name: 'Plan Tier',
                                         type: 'select', options: %w[Free Pro])

    assert_equal({ 'workspace_id' => 'ws_1' }, transport.last.query)
    assert_equal 'plan_tier', field.key
    assert_equal %w[Free Pro], field.options
  end

  def test_conversation_analytics_reads_the_analytics_route
    transport.stub(:get, '/analytics/inbox/conversations', json: {
                     'data' => {
                       'conversations' => [{
                         'key' => 't_1', 'accountId' => 'acc_1', 'platform' => 'instagram',
                         'received' => 9, 'sent' => 5, 'answered' => 5, 'open' => 1,
                         'medianResponseMinutes' => 47, 'firstMessageAt' => nil, 'lastMessageAt' => nil
                       }],
                       'total' => 128, 'page' => 1, 'perPage' => 25
                     }
                   })

    report = client.contacts.conversation_analytics(days: 30, sort: 'slowest')

    assert_equal '/v1/analytics/inbox/conversations', transport.last.path
    assert_equal 128, report.total
    assert_equal 47, report.conversations[0].median_response_minutes
  end
end
