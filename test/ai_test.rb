# frozen_string_literal: true

require 'test_helper'

class AiTest < Minitest::Test
  include ClientHelpers

  def test_credits_balance
    transport.stub(:get, '/ai/credits', json: {
                     'data' => { 'credits_remaining' => 940, 'credits_used' => 60, 'credits_total' => 1000,
                                 'period_start' => '2026-08-01T00:00:00.000Z' }
                   })

    balance = client.ai.credits

    assert_equal 940, balance.credits_remaining
    assert_equal Time.utc(2026, 8, 1), balance.period_start
  end

  def test_generate_caption_omits_unset_fields
    transport.stub(:post, '/ai/generate-caption', json: {
                     'caption' => 'Shipping something new.',
                     'credits' => { 'charged' => 2, 'remaining' => 938 }
                   })

    result = client.ai.generate_caption(current_caption: 'shipping a new feature', platforms: %w[twitter linkedin])

    assert_equal 'Shipping something new.', result.caption
    assert_equal 2, result.credits.charged
    assert_equal({ 'current_caption' => 'shipping a new feature', 'platforms' => %w[twitter linkedin] },
                 transport.last.json)
  end

  def test_rewrite_returns_one_variant_per_platform
    transport.stub(:post, '/ai/rewrite', json: {
                     'results' => [{ 'platform' => 'twitter', 'content' => 'Short.' },
                                   { 'platform' => 'linkedin', 'content' => 'Longer.' }],
                     'credits' => { 'charged' => 2, 'remaining' => 936 }
                   })

    result = client.ai.rewrite(content: 'A draft', platforms: %w[twitter linkedin])

    assert_equal %w[twitter linkedin], result.results.map(&:platform)
    assert_equal 936, result.credits.remaining
  end

  def test_repurpose_url_keeps_the_per_platform_map
    transport.stub(:post, '/ai/repurpose-url', json: {
                     'url' => 'https://example.com/post',
                     'title' => 'A post',
                     'posts' => { 'twitter' => 'Tweet', 'threads' => 'Thread' }
                   })

    result = client.ai.repurpose_url(url: 'https://example.com/post', platforms: %w[twitter threads])

    assert_equal 'A post', result.title
    assert_equal 'Tweet', result.posts['twitter']
  end

  def test_no_credits_raises_payment_required_with_an_upgrade_url
    transport.stub(:post, '/ai/rewrite', status: 402, json: {
                     'error' => 'insufficient_credits',
                     'message' => 'You have run out of AI credits.',
                     'upgrade_url' => 'https://fopost.com/dashboard/billing'
                   })

    error = assert_raises(Fopost::PaymentRequiredError) do
      client.ai.rewrite(content: 'A draft', platforms: ['twitter'])
    end

    assert_equal 'insufficient_credits', error.code
    assert_equal 'https://fopost.com/dashboard/billing', error.upgrade_url
  end
end
