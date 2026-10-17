# frozen_string_literal: true

require 'test_helper'

class BlogTest < Minitest::Test
  include ClientHelpers

  SETTINGS_FIXTURE = {
    'siteUrl' => 'https://yourbrand.com',
    'topic' => 'Running shoes',
    'audience' => nil,
    'goal' => 'leads',
    'focusTopics' => 'Trail running gear',
    'avoidTopics' => 'Competitor brands',
    'language' => 'en',
    'locationCode' => 2840,
    'cadencePerWeek' => 2,
    'reviewHoldDays' => 3,
    'imageTier' => 'standard',
    'inBodyImages' => 2,
    'minWords' => 900,
    'maxWords' => 1600,
    'brandVoiceId' => nil,
    'targetKind' => 'website',
    'targetAccountId' => nil,
    'targetPlatform' => nil,
    'websiteUrl' => 'https://yourbrand.com/fopost/articles',
    'hasWebsiteSecret' => true,
    'planRun' => { 'status' => 'done', 'error' => nil, 'added' => 12, 'finishedAt' => '2026-10-01T09:05:00.000Z' },
    'keywordDataAvailable' => true,
    'updatedAt' => '2026-10-01T09:00:00.000Z'
  }.freeze

  KEYWORD_FIXTURE = {
    'id' => 'kw_1',
    'keyword' => 'best trail running shoes',
    'searchVolume' => 4400,
    'difficulty' => 38,
    'cpc' => 1.2,
    'intent' => 'commercial',
    'source' => 'provider',
    'status' => 'planned',
    'plannedFor' => '2026-10-14',
    'fitReason' => 'Buyers compare shoes before they sign up.',
    'createdAt' => '2026-10-01T09:00:00.000Z'
  }.freeze

  IMAGE_FIXTURE = {
    'mediaId' => 'med_1',
    'url' => 'https://cdn.yourbrand.com/trail.jpg',
    'alt' => 'Trail shoes on a muddy path'
  }.freeze

  ARTICLE_FIXTURE = {
    'id' => 'art_1',
    'title' => 'The best trail running shoes of 2026',
    'slug' => 'best-trail-running-shoes-2026',
    'keyword' => 'best trail running shoes',
    'excerpt' => 'Grip, cushioning and drop, compared.',
    'metaTitle' => nil,
    'metaDescription' => nil,
    'featuredImage' => IMAGE_FIXTURE,
    'tags' => %w[shoes trail],
    'wordCount' => 1240,
    'status' => 'draft',
    'origin' => 'user',
    'reviewUntil' => '2026-10-04T09:00:00.000Z',
    'publishAt' => nil,
    'publishedAt' => nil,
    'publishedUrl' => nil,
    'error' => nil,
    'createdAt' => '2026-10-01T09:00:00.000Z',
    'updatedAt' => '2026-10-01T09:30:00.000Z'
  }.freeze

  ARTICLE_FULL_FIXTURE = ARTICLE_FIXTURE.merge(
    'instructions' => 'Lead with the comparison table.',
    'outline' => ['Why grip matters', 'Our picks'],
    'brief' => { 'competitors' => 3 },
    'bodyMarkdown' => '# The best trail running shoes',
    'bodyHtml' => '<h1>The best trail running shoes</h1>',
    'images' => [IMAGE_FIXTURE.merge('position' => 1)]
  ).freeze

  # ── Settings ──────────────────────────────────────────────────────

  def test_get_settings_reads_the_camel_case_body
    transport.stub(:get, '/blog/settings', json: { 'data' => SETTINGS_FIXTURE })

    settings = client.blog.get_settings('ws_1')

    assert_equal({ 'workspaceId' => 'ws_1' }, transport.last.query)
    assert_equal 2, settings.cadence_per_week
    assert_equal 'website', settings.target_kind
    assert settings.has_website_secret
    assert_equal Time.utc(2026, 10, 1, 9), settings.updated_at
  end

  def test_get_settings_reads_the_goal_and_the_last_plan_run
    transport.stub(:get, '/blog/settings', json: { 'data' => SETTINGS_FIXTURE })

    settings = client.blog.get_settings('ws_1')

    assert_equal 'leads', settings.goal
    assert_equal 'Trail running gear', settings.focus_topics
    assert_equal 'Competitor brands', settings.avoid_topics
    assert_equal 'done', settings.plan_run.status
    assert_equal 12, settings.plan_run.added
    assert_equal Time.utc(2026, 10, 1, 9, 5), settings.plan_run.finished_at
    refute_respond_to settings, :auto_publish
  end

  def test_get_settings_before_the_first_plan_run
    transport.stub(:get, '/blog/settings', json: { 'data' => SETTINGS_FIXTURE.merge('planRun' => nil) })

    assert_nil client.blog.get_settings('ws_1').plan_run
  end

  def test_update_settings_sends_only_what_was_passed_and_surfaces_the_secret_once
    transport.stub(:patch, '/blog/settings',
                   json: { 'data' => SETTINGS_FIXTURE, 'websiteSecret' => 'whsec_first' })

    result = client.blog.update_settings('ws_1', website_url: 'https://yourbrand.com/fopost/articles',
                                                 cadence_per_week: 2, brand_voice_id: nil)

    assert_equal 'PATCH', transport.last.method
    assert_equal({ 'workspaceId' => 'ws_1', 'websiteUrl' => 'https://yourbrand.com/fopost/articles',
                   'cadencePerWeek' => 2, 'brandVoiceId' => nil }, transport.last.json)
    assert_equal 'whsec_first', result.website_secret
    assert_equal 'https://yourbrand.com/fopost/articles', result.settings.website_url
  end

  def test_update_settings_sends_the_goal_and_topics
    transport.stub(:patch, '/blog/settings', json: { 'data' => SETTINGS_FIXTURE })

    client.blog.update_settings('ws_1', goal: 'leads', focus_topics: 'Trail running gear', avoid_topics: nil)

    assert_equal({ 'workspaceId' => 'ws_1', 'goal' => 'leads', 'focusTopics' => 'Trail running gear',
                   'avoidTopics' => nil }, transport.last.json)
  end

  def test_update_settings_without_a_new_secret_answers_nil
    transport.stub(:patch, '/blog/settings', json: { 'data' => SETTINGS_FIXTURE, 'websiteSecret' => nil })

    assert_nil client.blog.update_settings('ws_1', topic: 'Shoes').website_secret
  end

  def test_rotate_and_test_website
    transport.stub(:post, '/blog/settings/website-secret', json: { 'data' => { 'websiteSecret' => 'whsec_new' } })
    transport.stub(:post, '/blog/settings/website-test', json: { 'data' => { 'ok' => true, 'status' => 200,
                                                                             'error' => nil } })

    assert_equal 'whsec_new', client.blog.rotate_website_secret('ws_1')
    assert_equal({ 'workspaceId' => 'ws_1' }, transport.last.json)

    result = client.blog.test_website('ws_1')

    assert result.ok
    assert_equal 200, result.status
  end

  def test_a_failing_website_test_raises_the_base_error
    transport.stub(:post, '/blog/settings/website-test', status: 502,
                                                         json: { 'error' => 'website_unreachable',
                                                                 'message' => 'Timed out' })

    error = assert_raises(Fopost::Error) { client.blog.test_website('ws_1') }

    assert_equal 502, error.status
    assert_equal 'website_unreachable', error.code
  end

  # ── Keywords ──────────────────────────────────────────────────────

  def test_list_keywords_joins_statuses
    transport.stub(:get, '/blog/keywords', json: { 'data' => [KEYWORD_FIXTURE] })

    keywords = client.blog.list_keywords('ws_1', status: %w[suggested planned], limit: 20)

    assert_equal({ 'workspaceId' => 'ws_1', 'status' => 'suggested,planned', 'limit' => '20' }, transport.last.query)
    assert_equal 1, keywords.size
    assert_equal 4400, keywords[0].search_volume
    assert_equal '2026-10-14', keywords[0].planned_for
    assert_equal 'Buyers compare shoes before they sign up.', keywords[0].fit_reason
  end

  def test_suggest_seeds_posts_seeds_and_prompt_and_returns_the_terms
    transport.stub(:post, '/blog/keywords/suggest',
                   json: { 'data' => { 'seeds' => ['trail running shoes', 'waterproof trail shoes'] } })

    seeds = client.blog.suggest_seeds('ws_1', seeds: ['trail running'], prompt: 'Focus on beginners')

    assert_equal 'POST', transport.last.method
    assert_equal({ 'workspaceId' => 'ws_1', 'seeds' => ['trail running'], 'prompt' => 'Focus on beginners' },
                 transport.last.json)
    assert_equal ['trail running shoes', 'waterproof trail shoes'], seeds

    client.blog.suggest_seeds('ws_1')

    assert_equal({ 'workspaceId' => 'ws_1' }, transport.last.json)
  end

  def test_suggest_seeds_on_an_empty_balance_is_payment_required
    transport.stub(:post, '/blog/keywords/suggest', status: 402,
                                                    json: { 'error' => 'insufficient_credits',
                                                            'message' => 'Out of credits' })

    assert_raises(Fopost::PaymentRequiredError) { client.blog.suggest_seeds('ws_1') }
  end

  def test_plan_keywords_posts_seeds_and_reads_the_queued_answer
    transport.stub(:post, '/blog/keywords/plan', status: 202, json: { 'data' => { 'status' => 'queued' } })

    result = client.blog.plan_keywords('ws_1', seeds: ['trail running'])

    assert_equal({ 'workspaceId' => 'ws_1', 'seeds' => ['trail running'] }, transport.last.json)
    assert_equal 'queued', result['status']
  end

  def test_plan_keywords_on_an_empty_balance_is_payment_required
    transport.stub(:post, '/blog/keywords/plan', status: 402,
                                                 json: { 'error' => 'insufficient_credits',
                                                         'message' => 'Out of credits',
                                                         'upgrade_url' => 'https://app.fopost.com/billing' })

    error = assert_raises(Fopost::PaymentRequiredError) { client.blog.plan_keywords('ws_1') }

    assert_equal 'insufficient_credits', error.code
    assert_equal 'https://app.fopost.com/billing', error.upgrade_url
  end

  def test_add_update_and_delete_keyword
    transport.stub(:post, '/blog/keywords', status: 201, json: { 'data' => KEYWORD_FIXTURE })
    transport.stub(:patch, '/blog/keywords/kw_1', json: { 'data' => KEYWORD_FIXTURE.merge('status' => 'dismissed') })
    transport.stub(:delete, '/blog/keywords/kw_1', status: 204)

    keyword = client.blog.add_keyword('ws_1', keyword: 'best trail running shoes', planned_for: Date.new(2026, 10, 14))

    assert_equal({ 'workspaceId' => 'ws_1', 'keyword' => 'best trail running shoes', 'plannedFor' => '2026-10-14' },
                 transport.last.json)
    assert_equal 'kw_1', keyword.id

    updated = client.blog.update_keyword('ws_1', 'kw_1', status: 'dismissed', planned_for: nil)

    assert_equal '/v1/blog/keywords/kw_1', transport.last.path
    assert_equal({ 'workspaceId' => 'ws_1' }, transport.last.query)
    assert_equal({ 'status' => 'dismissed', 'plannedFor' => nil }, transport.last.json)
    assert_equal 'dismissed', updated.status

    assert_nil client.blog.delete_keyword('ws_1', 'kw_1')
    assert_equal 'DELETE', transport.last.method
    assert_equal({ 'workspaceId' => 'ws_1' }, transport.last.query)
  end

  # ── Articles ──────────────────────────────────────────────────────

  def test_list_articles
    transport.stub(:get, '/blog/articles', json: { 'data' => [ARTICLE_FIXTURE] })

    articles = client.blog.list_articles('ws_1', status: 'draft')

    assert_equal({ 'workspaceId' => 'ws_1', 'status' => 'draft' }, transport.last.query)
    assert_equal 'Trail shoes on a muddy path', articles[0].featured_image.alt
    assert_equal %w[shoes trail], articles[0].tags
    assert_equal Time.utc(2026, 10, 4, 9), articles[0].review_until
  end

  def test_request_article_sends_the_camel_case_body
    transport.stub(:post, '/blog/articles', status: 202,
                                            json: { 'data' => ARTICLE_FIXTURE.merge('status' => 'queued') })

    article = client.blog.request_article('ws_1', keyword_id: 'kw_1', instructions: 'Lead with the table.')

    assert_equal({ 'workspaceId' => 'ws_1', 'keywordId' => 'kw_1', 'instructions' => 'Lead with the table.' },
                 transport.last.json)
    assert_equal 'queued', article.status
    assert_instance_of Fopost::BlogArticle, article
  end

  def test_get_article_returns_the_full_body
    transport.stub(:get, '/blog/articles/art_1', json: { 'data' => ARTICLE_FULL_FIXTURE })

    article = client.blog.get_article('ws_1', 'art_1')

    assert_equal({ 'workspaceId' => 'ws_1' }, transport.last.query)
    assert_instance_of Fopost::BlogArticleFull, article
    assert_equal '# The best trail running shoes', article.body_markdown
    assert_equal ['Why grip matters', 'Our picks'], article.outline
    assert_equal 1, article.images[0].position
    assert_equal({ 'competitors' => 3 }, article.brief)
  end

  def test_update_article_is_partial_and_formats_publish_at
    transport.stub(:patch, '/blog/articles/art_1', json: { 'data' => ARTICLE_FULL_FIXTURE })

    client.blog.update_article('ws_1', 'art_1', title: 'New title', publish_at: Time.utc(2026, 10, 20, 8))

    assert_equal({ 'workspaceId' => 'ws_1' }, transport.last.query)
    assert_equal({ 'title' => 'New title', 'publishAt' => '2026-10-20T08:00:00Z' }, transport.last.json)

    client.blog.update_article('ws_1', 'art_1', publish_at: nil)

    assert_equal({ 'publishAt' => nil }, transport.last.json)
  end

  def test_update_article_in_the_wrong_state_is_a_409_base_error
    transport.stub(:patch, '/blog/articles/art_1', status: 409,
                                                   json: { 'error' => 'invalid_state', 'message' => 'Not editable' })

    error = assert_raises(Fopost::Error) { client.blog.update_article('ws_1', 'art_1', title: 'x') }

    assert_equal 409, error.status
    assert_equal 'invalid_state', error.code
  end

  def test_regenerate_publish_reject_and_delete_carry_the_workspace_in_the_query
    %w[regenerate publish reject].each do |action|
      transport.stub(:post, "/blog/articles/art_1/#{action}", status: 202, json: { 'data' => ARTICLE_FIXTURE })
    end
    transport.stub(:delete, '/blog/articles/art_1', status: 204)

    assert_equal 'art_1', client.blog.regenerate_article('ws_1', 'art_1').id
    assert_equal '/v1/blog/articles/art_1/regenerate', transport.last.path
    assert_nil transport.last.body

    client.blog.publish_article('ws_1', 'art_1')

    assert_equal '/v1/blog/articles/art_1/publish', transport.last.path
    assert_equal({ 'workspaceId' => 'ws_1' }, transport.last.query)

    client.blog.reject_article('ws_1', 'art_1')

    assert_equal '/v1/blog/articles/art_1/reject', transport.last.path

    assert_nil client.blog.delete_article('ws_1', 'art_1')
    assert_equal({ 'workspaceId' => 'ws_1' }, transport.last.query)
  end

  def test_submit_article_moves_it_to_review
    transport.stub(:post, '/blog/articles/art_1/submit',
                   json: { 'data' => ARTICLE_FIXTURE.merge('status' => 'in_review') })

    article = client.blog.submit_article('ws_1', 'art_1')

    assert_equal 'POST', transport.last.method
    assert_equal '/v1/blog/articles/art_1/submit', transport.last.path
    assert_equal({ 'workspaceId' => 'ws_1' }, transport.last.query)
    assert_nil transport.last.body
    assert_equal 'in_review', article.status
    assert_includes Fopost::BLOG_ARTICLE_STATUSES, article.status
  end

  def test_submitting_an_article_in_the_wrong_state_is_a_conflict
    transport.stub(:post, '/blog/articles/art_1/submit', status: 409,
                                                         json: { 'error' => 'invalid_state',
                                                                 'message' => 'Only a draft can be submitted' })

    error = assert_raises(Fopost::Error) { client.blog.submit_article('ws_1', 'art_1') }

    assert_equal 409, error.status
    assert_equal 'invalid_state', error.code
  end

  def test_publish_without_a_target_is_a_conflict
    transport.stub(:post, '/blog/articles/art_1/publish', status: 409,
                                                          json: { 'error' => 'no_target',
                                                                  'message' => 'Nowhere to publish' })

    error = assert_raises(Fopost::Error) { client.blog.publish_article('ws_1', 'art_1') }

    assert_equal 'no_target', error.code
  end
end
