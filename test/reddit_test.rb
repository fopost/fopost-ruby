# frozen_string_literal: true

require 'test_helper'

class RedditTest < Minitest::Test
  include ClientHelpers

  SUBREDDIT = {
    'name' => 'webdev',
    'title' => 'Web Development',
    'subscribers' => 2_000_000,
    'over18' => false,
    'canPost' => true,
    'flairEnabled' => true,
    'iconUrl' => nil,
    'isDefault' => true
  }.freeze

  def test_subreddits_rules_and_flairs
    transport.stub(:get, '/accounts/acc_1/reddit/subreddits', json: { 'data' => [SUBREDDIT] })
    subreddits = client.accounts.list_reddit_subreddits('acc_1')

    assert_equal '/v1/accounts/acc_1/reddit/subreddits', transport.last.path
    assert_equal 'webdev', subreddits.first.name
    assert subreddits.first.is_default

    transport.stub(:get, '/accounts/acc_1/reddit/subreddits/webdev/rules', json: {
                     'data' => {
                       'subreddit' => 'webdev',
                       'rules' => [{ 'name' => 'No self promotion', 'description' => 'Keep it useful',
                                     'appliesTo' => 'link' }]
                     }
                   })
    rules = client.accounts.list_reddit_subreddit_rules('acc_1', 'webdev')

    assert_equal '/v1/accounts/acc_1/reddit/subreddits/webdev/rules', transport.last.path
    assert_equal 'link', rules.rules.first.applies_to

    transport.stub(:get, '/accounts/acc_1/reddit/flairs', json: {
                     'data' => {
                       'subreddit' => 'webdev',
                       'flairs' => [{ 'id' => 'flair-1', 'text' => 'Showoff Saturday', 'editable' => false }]
                     }
                   })
    flairs = client.accounts.list_reddit_flairs('acc_1', 'webdev')

    assert_equal({ 'subreddit' => 'webdev' }, transport.last.query)
    assert_equal 'flair-1', flairs.flairs.first.id
  end

  def test_default_subreddit_accepts_nil
    transport.stub(:put, '/accounts/acc_1/reddit/default-subreddit', json: { 'data' => { 'subreddit' => nil } })
    result = client.accounts.set_reddit_default_subreddit('acc_1', nil)

    assert_equal({ 'subreddit' => nil }, transport.last.json)
    assert_nil result.subreddit
  end

  def test_validate_subreddit
    transport.stub(:get, '/validate/subreddit', json: {
                     'data' => { 'subreddit' => 'webdev', 'exists' => true, 'can_post' => true,
                                 'over_18' => false, 'flair_enabled' => true, 'ok' => true }
                   })
    check = client.validate.subreddit(account_id: 'acc_1', name: 'webdev')

    assert_equal({ 'account_id' => 'acc_1', 'name' => 'webdev' }, transport.last.query)
    assert check.ok
  end

  def test_vote_sends_the_direction
    transport.stub(:post, '/inbox/i_1/vote', json: {
                     'data' => { 'id' => 'i_1', 'platform' => 'reddit', 'type' => 'comment',
                                 'state' => 'unread', 'vote' => 'down', 'canVote' => true }
                   })
    item = client.inbox.vote('i_1', 'down')

    assert_equal '/v1/inbox/i_1/vote', transport.last.path
    assert_equal({ 'direction' => 'down' }, transport.last.json)
    assert_equal 'down', item.vote
    assert item.can_vote
  end

  def test_a_stale_grant_is_an_api_error
    transport.stub(:get, '/accounts/acc_1/reddit/subreddits', status: 409,
                                                              json: { 'error' => 'reconnect_required',
                                                                      'message' => 'Reconnect this account' })

    error = assert_raises(Fopost::Error) { client.accounts.list_reddit_subreddits('acc_1') }
    assert_equal 409, error.status
    assert_equal 'reconnect_required', error.code
  end
end
