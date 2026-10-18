# frozen_string_literal: true

require 'test_helper'

class XTest < Minitest::Test
  include ClientHelpers

  X_POST = {
    'id' => '1790000000000000001',
    'text' => 'Shipping day.',
    'permalink' => 'https://x.com/yourbrand/status/1790000000000000001',
    'author_name' => 'Your Brand',
    'author_handle' => 'yourbrand',
    'author_avatar_url' => nil,
    'author_followers' => 1200,
    'conversation_id' => '1790000000000000001',
    'parent_external_id' => nil,
    'likes' => 12,
    'replies' => 3,
    'reposts' => 4,
    'quotes' => 1,
    'platform_created_at' => '2026-10-18T09:00:00.000Z'
  }.freeze

  def test_follow_and_unfollow_send_the_user_id
    transport
      .stub(:post, '/accounts/acc_1/x/follow',
            json: { 'data' => { 'account_id' => 'acc_1', 'user_id' => '12345', 'following' => true } })
      .stub(:post, '/accounts/acc_1/x/unfollow',
            json: { 'data' => { 'account_id' => 'acc_1', 'user_id' => '12345', 'following' => false } })

    result = client.accounts.follow_x_user('acc_1', user_id: '12345')

    assert_equal 'POST', transport.last.method
    assert_equal '/v1/accounts/acc_1/x/follow', transport.last.path
    assert_equal({ 'user_id' => '12345' }, transport.last.json)
    assert_equal 'acc_1', result.account_id
    assert_equal '12345', result.user_id
    assert result.following

    refute client.accounts.unfollow_x_user('acc_1', user_id: '12345').following
    assert_equal '/v1/accounts/acc_1/x/unfollow', transport.last.path
  end

  def test_x_post_reads_with_the_account
    transport.stub(:get, '/x/posts/1790000000000000001', json: { 'data' => X_POST })

    post = client.accounts.x_post('1790000000000000001', account_id: 'acc_1')

    assert_equal 'GET', transport.last.method
    assert_equal '/v1/x/posts/1790000000000000001', transport.last.path
    assert_equal({ 'account_id' => 'acc_1' }, transport.last.query)
    assert_equal '1790000000000000001', post.id
    assert_equal 'yourbrand', post.author_handle
    assert_equal 4, post.reposts
    assert_equal Time.utc(2026, 10, 18, 9), post.platform_created_at
  end

  def test_search_x_posts_sends_filters_and_reads_the_next_token
    transport.stub(:get, '/x/search', json: { 'data' => [X_POST], 'meta' => { 'next_token' => 'b26v89c' } })

    page = client.accounts.search_x_posts('launch day', account_id: 'acc_1', max_results: 50, next_token: 'a1')

    assert_equal '/v1/x/search', transport.last.path
    assert_equal({ 'q' => 'launch day', 'account_id' => 'acc_1', 'max_results' => '50', 'next_token' => 'a1' },
                 transport.last.query)
    assert_equal 1, page.posts.size
    assert_equal 'Shipping day.', page.posts.first.text
    assert_equal 'b26v89c', page.next_token
  end

  def test_search_x_posts_omits_blank_filters_and_nil_next_token
    transport.stub(:get, '/x/search', json: { 'data' => [], 'meta' => { 'next_token' => nil } })

    page = client.accounts.search_x_posts('launch day', account_id: 'acc_1')

    assert_equal({ 'q' => 'launch day', 'account_id' => 'acc_1' }, transport.last.query)
    assert_empty page.posts
    assert_nil page.next_token
  end
end
