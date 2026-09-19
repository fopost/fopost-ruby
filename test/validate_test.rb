# frozen_string_literal: true

require 'test_helper'

class ValidateTest < Minitest::Test
  include ClientHelpers

  def test_post_sends_content_media_and_platforms
    transport.stub(:post, '/validate/post', json: {
                     'data' => {
                       'ready' => false,
                       'platforms' => [
                         { 'platform' => 'twitter', 'ready' => false, 'issues' => ['Text is too long'],
                           'score' => 61, 'signals' => [{ 'level' => 'warn', 'code' => 'no_hashtags',
                                                          'message' => 'Add a hashtag' }] },
                         { 'platform' => 'linkedin', 'ready' => true, 'issues' => [], 'signals' => [] }
                       ]
                     }
                   })

    media = [{ url: 'https://example.com/a.png', mime_type: 'image/png', size: 1024 }]
    result = client.validate.post(content: 'Hello', media: media, platforms: %w[twitter linkedin])

    assert_equal '/v1/validate/post', transport.last.path
    assert_equal({ 'content' => 'Hello',
                   'media' => [{ 'url' => 'https://example.com/a.png', 'mime_type' => 'image/png', 'size' => 1024 }],
                   'platforms' => %w[twitter linkedin] }, transport.last.json)
    refute result.ready
    assert_equal ['Text is too long'], result.platforms.first.issues
    assert_equal 61, result.platforms.first.score
    assert_equal 'no_hashtags', result.platforms.first.signals.first.code
    assert result.platforms.last.ready
  end

  def test_length_sends_text_and_platforms
    transport.stub(:post, '/validate/length', json: {
                     'data' => {
                       'ok' => false,
                       'platforms' => [
                         { 'platform' => 'twitter', 'length' => 300, 'limit' => 280, 'unit' => 'chars', 'ok' => false,
                           'signals' => [{ 'level' => 'warn', 'code' => 'over_length', 'message' => '20 over' }] },
                         { 'platform' => 'linkedin', 'length' => 300, 'limit' => nil, 'unit' => 'chars', 'ok' => true,
                           'signals' => [] }
                       ]
                     }
                   })

    result = client.validate.length(text: 'x' * 300, platforms: %w[twitter linkedin])

    assert_equal '/v1/validate/length', transport.last.path
    assert_equal({ 'text' => 'x' * 300, 'platforms' => %w[twitter linkedin] }, transport.last.json)
    refute result.ok
    assert_equal 280, result.platforms.first.limit
    assert_equal 'over_length', result.platforms.first.signals.first.code
    assert_nil result.platforms.last.limit
  end

  def test_media_sends_the_url
    transport.stub(:post, '/validate/media', json: {
                     'data' => { 'ok' => true, 'issues' => [], 'name' => 'a.png', 'size' => 1024,
                                 'mime_type' => 'image/png', 'type' => 'image' }
                   })

    result = client.validate.media(url: 'https://example.com/a.png')

    assert_equal '/v1/validate/media', transport.last.path
    assert_equal({ 'url' => 'https://example.com/a.png' }, transport.last.json)
    assert result.ok
    assert_equal 'image/png', result.mime_type
    assert_equal 'image', result.type
  end
end
