# frozen_string_literal: true

require 'test_helper'

class PostsTest < Minitest::Test
  include ClientHelpers

  def test_list_returns_posts_and_meta
    transport.stub(:get, '/posts', json: {
                     'data' => [POST_FIXTURE],
                     'meta' => { 'current_page' => 1, 'per_page' => 30, 'total' => 1,
                                 'last_page' => 1, 'from' => 1, 'to' => 1 }
                   })

    page = client.posts.list(workspace_id: 'ws_1', status: 'draft')

    assert_equal 1, page.size
    assert_instance_of Fopost::Post, page[0]
    assert_equal 'post_1', page[0].id
    assert_equal 'Hello from Ruby', page[0].content[0].text
    assert_equal 1, page.meta.total
    assert_equal 1, page.meta.from
    assert_equal ['post_1'], page.map(&:id)

    assert_equal({ 'workspace_id' => 'ws_1', 'status' => 'draft', 'page' => '1', 'per_page' => '30' },
                 transport.last.query)
  end

  def test_get_unwraps_a_bare_post
    transport.stub(:get, '/posts/post_1', json: POST_FIXTURE)

    post = client.posts.get('post_1')

    assert_equal 'post_1', post.id
    assert_equal 'ws_1', post.workspace_id
    assert_equal Time.utc(2026, 8, 12, 10, 0, 0), post.created_at
  end

  def test_create_sends_the_shape_the_api_validates
    transport.stub(:post, '/posts', status: 201, json: POST_FIXTURE)

    post = client.posts.create(workspace_id: 'ws_1', content: 'Hello from Ruby',
                               accounts: ['acc_1'], labels: ['lbl_1'])

    assert_equal 'post_1', post.id
    assert_equal({
                   'workspace_id' => 'ws_1',
                   'status' => 'draft',
                   'content' => [{ 'text' => 'Hello from Ruby' }],
                   'accounts' => ['acc_1'],
                   'labels' => ['lbl_1']
                 }, transport.last.json)
  end

  def test_create_with_an_account_group
    transport.stub(:post, '/posts', status: 201, json: POST_FIXTURE)

    client.posts.create(workspace_id: 'ws_1', content: 'Hi', account_group_id: 'grp_1')

    assert_equal 'grp_1', transport.last.json['account_group_id']
    assert_empty transport.last.json['accounts']
  end

  def test_create_accepts_account_objects_blocks_and_times
    transport.stub(:post, '/posts', status: 201, json: POST_FIXTURE)

    client.posts.create(
      workspace_id: 'ws_1',
      content: [{ 'text' => 'Block one' }, 'Block two'],
      accounts: [{ 'id' => 'acc_1' }, 'acc_2', Fopost::SocialAccount.new(ACCOUNT_FIXTURE)],
      status: 'scheduled',
      schedule_at: Time.utc(2026, 9, 1, 10, 0, 0)
    )

    body = transport.last.json

    assert_equal %w[acc_1 acc_2 acc_1], body['accounts']
    assert_equal [{ 'text' => 'Block one' }, { 'text' => 'Block two' }], body['content']
    assert_equal '2026-09-01T10:00:00Z', body['schedule_at']
  end

  def test_create_rejects_an_account_it_cannot_read
    assert_raises(ArgumentError) do
      client.posts.create(workspace_id: 'ws_1', content: 'x', accounts: [{ 'name' => 'no id' }])
    end
  end

  def test_update_only_sends_named_fields
    transport.stub(:put, '/posts/post_1', json: POST_FIXTURE)

    client.posts.update('post_1', title: 'Renamed')

    assert_equal({ 'title' => 'Renamed' }, transport.last.json)
  end

  def test_update_can_clear_a_field
    transport.stub(:put, '/posts/post_1', json: POST_FIXTURE)

    client.posts.update('post_1', schedule_at: nil)

    assert_equal({ 'schedule_at' => nil }, transport.last.json)
  end

  def test_delete_returns_nil
    transport.stub(:delete, '/posts/post_1', status: 204)

    assert_nil client.posts.delete('post_1')
    assert_equal 'DELETE', transport.last.method
  end

  def test_lifecycle_actions_post_to_their_endpoint
    %w[publish cancel retry preflight].each do |action|
      transport.stub(:post, "/posts/post_1/#{action}", json: { 'data' => { 'status' => 'queued' } })

      assert_equal({ 'status' => 'queued' }, client.posts.public_send(action, 'post_1'))
      assert_equal "#{BASE_PATH}/posts/post_1/#{action}", transport.last.path
    end
  end

  def test_deliveries_parses_camel_case_rows
    transport.stub(:get, '/posts/post_1/deliveries', json: {
                     'data' => [{ 'id' => 'del_1', 'accountId' => 'acc_1', 'status' => 'published',
                                  'platformPostId' => '123', 'postedAt' => '2026-08-12T11:00:00.000Z' }]
                   })

    delivery = client.posts.deliveries('post_1').first

    assert_equal 'acc_1', delivery.account_id
    assert_equal '123', delivery.platform_post_id
    assert_equal Time.utc(2026, 8, 12, 11, 0, 0), delivery.posted_at
  end

  def test_each_walks_every_page
    page_two = POST_FIXTURE.merge('id' => 'post_2')
    transport
      .stub(:get, '/posts', json: { 'data' => [POST_FIXTURE],
                                    'meta' => { 'current_page' => 1, 'last_page' => 2, 'per_page' => 1 } })
      .stub(:get, '/posts', json: { 'data' => [page_two],
                                    'meta' => { 'current_page' => 2, 'last_page' => 2, 'per_page' => 1 } })

    ids = client.posts.each(workspace_id: 'ws_1', per_page: 1).map(&:id)

    assert_equal %w[post_1 post_2], ids
    assert_equal(%w[1 2], transport.calls.map { |call| call.query['page'] })
  end

  def test_each_page_stops_on_a_short_page_without_meta
    transport.stub(:get, '/posts', json: { 'data' => [POST_FIXTURE] })

    pages = client.posts.each_page(per_page: 30).to_a

    assert_equal 1, pages.size
    assert_equal 1, transport.calls.size
  end
end
