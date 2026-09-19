# frozen_string_literal: true

require 'test_helper'

class InboxTest < Minitest::Test
  include ClientHelpers

  INBOX_ITEM_FIXTURE = {
    'id' => 'inb_1',
    'workspaceId' => 'ws_1',
    'platform' => 'instagram',
    'type' => 'comment',
    'state' => 'unread',
    'authorName' => 'Jordan Vale',
    'authorHandle' => 'jordanvale',
    'text' => 'Love this launch!',
    'attachments' => [{ 'kind' => 'image', 'url' => 'https://api.fopost.com/v1/inbox/inb_1/attachments/0' }],
    'postExternalId' => 'ig_post_9',
    'platformCreatedAt' => '2026-09-18T10:00:00.000Z',
    'canReply' => true,
    'hidden' => false,
    'account' => { 'id' => 'acc_1', 'platform' => 'instagram', 'username' => 'yourbrand' }
  }.freeze

  def test_list_sends_snake_case_filters_and_parses_the_page
    transport.stub(:get, '/inbox', json: {
                     'data' => [INBOX_ITEM_FIXTURE],
                     'meta' => { 'page' => 2, 'perPage' => 10, 'total' => 41 }
                   })

    page = client.inbox.list(workspace_id: 'ws_1', type: 'comment', state: 'unread', sort: 'unanswered',
                             page: 2, per_page: 10)

    assert_equal 'GET', transport.last.method
    assert_equal '/v1/inbox', transport.last.path
    assert_equal({ 'workspace_id' => 'ws_1', 'type' => 'comment', 'state' => 'unread', 'sort' => 'unanswered',
                   'page' => '2', 'per_page' => '10' }, transport.last.query)

    assert_equal 41, page.meta.total
    assert_equal 2, page.meta.page
    item = page.first

    assert_equal 'inb_1', item.id
    assert_equal 'ws_1', item.workspace_id
    assert_equal 'jordanvale', item.author_handle
    assert_equal 'image', item.attachments[0].kind
    assert_equal 'yourbrand', item.account.username
    assert_equal Time.utc(2026, 9, 18, 10), item.platform_created_at
    assert item.can_reply
  end

  def test_threads_and_conversations_read_their_own_paths
    transport
      .stub(:get, '/inbox/posts', json: {
              'data' => [{ 'accountId' => 'acc_1', 'postExternalId' => 'ig_post_9', 'commentCount' => 3,
                           'unreadCount' => 1, 'post' => { 'externalId' => 'ig_post_9', 'isOwn' => true } }],
              'meta' => { 'page' => 1, 'perPage' => 25, 'total' => 1 }
            })
      .stub(:get, '/inbox/conversations', json: {
              'data' => [{ 'accountId' => 'acc_1', 'conversationId' => 'conv_1', 'messageCount' => 4,
                           'unreadCount' => 2, 'lastMessageOutbound' => false }],
              'meta' => { 'page' => 1, 'perPage' => 25, 'total' => 1 }
            })

    threads = client.inbox.threads(workspace_id: 'ws_1', kind: 'mentions')

    assert_equal({ 'workspace_id' => 'ws_1', 'kind' => 'mentions', 'page' => '1', 'per_page' => '25' },
                 transport.last.query)
    assert_equal 3, threads[0].comment_count
    assert threads[0].post.is_own

    conversations = client.inbox.conversations(workspace_id: 'ws_1')

    assert_equal 'conv_1', conversations[0].conversation_id
    assert_equal 2, conversations[0].unread_count
  end

  def test_unread_count_answers_bare
    transport.stub(:get, '/inbox/unread-count', json: { 'count' => 7 })

    assert_equal 7, client.inbox.unread_count(workspace_id: 'ws_1')
    assert_equal({ 'workspace_id' => 'ws_1' }, transport.last.query)
  end

  def test_accounts_and_platforms
    transport
      .stub(:get, '/inbox/accounts', json: { 'data' => [{ 'id' => 'acc_1', 'platform' => 'instagram',
                                                          'inboxSupported' => true, 'dmSupported' => false,
                                                          'dmPendingReason' => 'approval' }] })
      .stub(:get, '/inbox/platforms', json: { 'data' => [{ 'platform' => 'instagram', 'comments' => 'supported',
                                                           'dms' => 'pending' }] })

    accounts = client.inbox.accounts(workspace_id: 'ws_1')

    assert accounts[0].inbox_supported
    refute accounts[0].dm_supported
    assert_equal 'approval', accounts[0].dm_pending_reason

    platforms = client.inbox.platforms

    assert_equal 'pending', platforms[0].dms
    assert_nil transport.last.uri.query
  end

  def test_mark_thread_read_posts_snake_case_and_returns_the_count
    transport.stub(:post, '/inbox/read', json: { 'data' => { 'updated' => 3 } })

    updated = client.inbox.mark_thread_read(workspace_id: 'ws_1', account_id: 'acc_1', post_external_id: 'ig_post_9')

    assert_equal 3, updated
    assert_equal({ 'workspace_id' => 'ws_1', 'account_id' => 'acc_1', 'post_external_id' => 'ig_post_9' },
                 transport.last.json)
  end

  def test_refresh
    transport.stub(:post, '/inbox/refresh', json: {
                     'data' => { 'accountsPolled' => 2, 'newItems' => 5, 'rateLimited' => 0,
                                 'dmReconnect' => [{ 'platform' => 'instagram', 'account' => 'yourbrand' }] }
                   })

    result = client.inbox.refresh(workspace_id: 'ws_1')

    assert_equal({ 'workspace_id' => 'ws_1' }, transport.last.json)
    assert_equal 5, result.new_items
    assert_equal 'yourbrand', result.dm_reconnect[0]['account']
  end

  def test_update_patches_state_and_formats_the_snooze
    transport.stub(:patch, '/inbox/inb_1', json: { 'data' => INBOX_ITEM_FIXTURE.merge('state' => 'snoozed') })

    item = client.inbox.update('inb_1', state: 'snoozed', snoozed_until: Time.utc(2026, 9, 20, 9))

    assert_equal 'PATCH', transport.last.method
    assert_equal '/v1/inbox/inb_1', transport.last.path
    assert_equal({ 'state' => 'snoozed', 'snoozedUntil' => '2026-09-20T09:00:00Z' }, transport.last.json)
    assert_equal 'snoozed', item.state
  end

  def test_update_omits_an_absent_snooze
    transport.stub(:patch, '/inbox/inb_1', json: { 'data' => INBOX_ITEM_FIXTURE.merge('state' => 'read') })

    client.inbox.update('inb_1', state: 'read')

    assert_equal({ 'state' => 'read' }, transport.last.json)
  end

  def test_reply_returns_the_item_and_the_platform_reply
    transport.stub(:post, '/inbox/inb_1/reply', json: {
                     'data' => { 'item' => INBOX_ITEM_FIXTURE.merge('repliedAt' => '2026-09-18T11:00:00.000Z'),
                                 'reply' => { 'externalId' => 'ig_c_2', 'externalUrl' => nil } }
                   })

    result = client.inbox.reply('inb_1', text: 'Thanks!')

    assert_equal({ 'text' => 'Thanks!' }, transport.last.json)
    assert_equal Time.utc(2026, 9, 18, 11), result.item.replied_at
    assert_equal 'ig_c_2', result.reply['externalId']
  end

  def test_hide_unhide_and_delete
    transport
      .stub(:post, '/inbox/inb_1/hide', json: { 'data' => INBOX_ITEM_FIXTURE.merge('hidden' => true) })
      .stub(:post, '/inbox/inb_1/unhide', json: { 'data' => INBOX_ITEM_FIXTURE })
      .stub(:delete, '/inbox/inb_1', json: { 'data' => { 'deleted' => true } })

    assert client.inbox.hide('inb_1').hidden
    refute client.inbox.unhide('inb_1').hidden
    assert_nil client.inbox.delete('inb_1')
    assert_equal 'DELETE', transport.last.method
  end

  def test_approvals_approve_and_reject
    transport
      .stub(:get, '/inbox/approvals', json: { 'data' => [{ 'id' => 12, 'source' => 'agent', 'reply' => 'Draft',
                                                           'createdAt' => '2026-09-18T12:00:00.000Z' }] })
      .stub(:post, '/inbox/approvals/12/approve', json: { 'data' => { 'id' => 12, 'outcome' => 'sent' } })
      .stub(:post, '/inbox/approvals/13/reject', json: { 'data' => { 'id' => 13, 'outcome' => 'rejected' } })

    approvals = client.inbox.approvals(workspace_id: 'ws_1')

    assert_equal 12, approvals[0].id
    assert_equal 'Draft', approvals[0].reply

    assert_equal({ 'id' => 12, 'outcome' => 'sent' }, client.inbox.approve_reply(12, text: 'Edited'))
    assert_equal({ 'text' => 'Edited' }, transport.last.json)

    assert_equal 'rejected', client.inbox.reject_reply(13)['outcome']
    assert_equal '/v1/inbox/approvals/13/reject', transport.last.path
  end

  def test_approve_without_text_sends_an_empty_body
    transport.stub(:post, '/inbox/approvals/12/approve', json: { 'data' => { 'id' => 12, 'outcome' => 'sent' } })

    client.inbox.approve_reply(12)

    assert_equal({}, transport.last.json)
  end
end
