# frozen_string_literal: true

require 'test_helper'
require 'openssl'

class WebhooksTest < Minitest::Test
  SECRET = 'whsec_test'
  NOW = Time.utc(2026, 10, 11, 12, 0, 0)

  PAYLOAD = {
    'event' => 'article.published',
    'data' => {
      'id' => 'art_1',
      'title' => 'The best trail running shoes of 2026',
      'slug' => 'best-trail-running-shoes-2026',
      'excerpt' => nil,
      'metaTitle' => nil,
      'metaDescription' => nil,
      'bodyMarkdown' => '# Shoes',
      'bodyHtml' => '<h1>Shoes</h1>',
      'featuredImage' => { 'mediaId' => 'med_1', 'url' => 'https://cdn.yourbrand.com/a.jpg', 'alt' => 'Shoes' },
      'images' => [],
      'tags' => ['shoes'],
      'keyword' => 'trail shoes',
      'wordCount' => 1200,
      'publishedAt' => '2026-10-11T11:59:00.000Z',
      'publishedUrl' => 'https://yourbrand.com/blog/best-trail-running-shoes-2026'
    },
    'timestamp' => '2026-10-11T11:59:30.000Z'
  }.freeze

  def raw_body
    # Key order deliberately differs from a re-serialisation of the parsed hash.
    @raw_body ||= JSON.generate(PAYLOAD).sub('"event"', ' "event"')
  end

  def hmac(payload)
    "sha256=#{OpenSSL::HMAC.hexdigest('SHA256', SECRET, payload)}"
  end

  def timestamped_headers(timestamp: NOW.to_i, body: raw_body)
    {
      'X-FoPost-Signature' => hmac(body),
      'X-FoPost-Timestamp' => timestamp.to_s,
      'X-FoPost-Signature-256' => hmac("#{timestamp}.#{body}"),
      'X-FoPost-Event' => 'article.published'
    }
  end

  def test_a_valid_timestamped_signature_returns_the_typed_envelope
    event = Fopost::Webhooks.verify(raw_body, timestamped_headers, SECRET, now: NOW)

    assert_instance_of Fopost::WebhookEvent, event
    assert_equal 'article.published', event.event
    assert_equal Time.utc(2026, 10, 11, 11, 59, 30), event.timestamp
    assert_equal 'art_1', event.data['id']

    article = event.article

    assert_instance_of Fopost::BlogArticlePublished, article
    assert_equal 'https://yourbrand.com/blog/best-trail-running-shoes-2026', article.published_url
    assert_equal 'Shoes', article.featured_image.alt
    assert_equal 1200, article.word_count
  end

  def test_a_tampered_body_fails
    tampered = raw_body.sub('art_1', 'art_2')

    assert_raises(Fopost::WebhookSignatureError) do
      Fopost::Webhooks.verify(tampered, timestamped_headers, SECRET, now: NOW)
    end
  end

  def test_a_stale_timestamp_fails_even_with_a_matching_signature
    headers = timestamped_headers(timestamp: NOW.to_i - 301)

    error = assert_raises(Fopost::WebhookSignatureError) do
      Fopost::Webhooks.verify(raw_body, headers, SECRET, now: NOW)
    end

    assert_match(/tolerance/, error.message)
    assert Fopost::Webhooks.verify(raw_body, timestamped_headers(timestamp: NOW.to_i - 300), SECRET, now: NOW)
  end

  def test_the_timestamp_wins_over_a_valid_plain_signature
    headers = timestamped_headers.merge('X-FoPost-Signature-256' => hmac("1.#{raw_body}"))

    assert_raises(Fopost::WebhookSignatureError) { Fopost::Webhooks.verify(raw_body, headers, SECRET, now: NOW) }
  end

  def test_the_plain_body_signature_passes_only_when_no_timestamp_was_sent
    event = Fopost::Webhooks.verify(raw_body, { 'x-fopost-signature' => hmac(raw_body) }, SECRET, now: NOW)

    assert_equal 'article.published', event.event

    assert_raises(Fopost::WebhookSignatureError) do
      Fopost::Webhooks.verify(raw_body, { 'x-fopost-signature' => hmac('other') }, SECRET, now: NOW)
    end
    assert_raises(Fopost::WebhookSignatureError) { Fopost::Webhooks.verify(raw_body, {}, SECRET, now: NOW) }
  end

  def test_rack_style_header_names_are_accepted
    headers = { 'HTTP_X_FOPOST_SIGNATURE_256' => hmac("#{NOW.to_i}.#{raw_body}"),
                'HTTP_X_FOPOST_TIMESTAMP' => NOW.to_i }

    assert_equal 'article.published', Fopost::Webhooks.verify(raw_body, headers, SECRET, now: NOW).event
  end

  def test_a_missing_secret_is_refused_before_any_compare
    assert_raises(Fopost::WebhookSignatureError) { Fopost::Webhooks.verify(raw_body, timestamped_headers, '') }
  end

  def test_sign_matches_the_header_the_api_sends
    assert_equal hmac(raw_body), Fopost::Webhooks.sign(raw_body, SECRET)
  end
end
