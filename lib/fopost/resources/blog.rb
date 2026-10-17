# frozen_string_literal: true

module Fopost
  module Resources
    # `client.blog` — articles written for a website, as opposed to posts
    # that go to a social network.
    #
    # Reads, settings and keyword edits need the `posts` scope. Anything that
    # spends credits ({#plan_keywords}, {#request_article},
    # {#regenerate_article}) needs `ai` and answers 402 on an empty balance;
    # {#publish_article} needs `publish` and answers 409 `no_target` when the
    # settings name nowhere to publish.
    class Blog < Base
      # ── Settings ──────────────────────────────────────────────────

      def get_settings(workspace_id)
        BlogSettings.new(unwrap(http.get('/blog/settings', { 'workspaceId' => workspace_id })))
      end

      # Partial update: only what you pass is sent.
      #
      # The answer carries `website_secret` only on the update that first sets
      # `website_url`; keep it, it is never shown again. Pass `nil` to clear a
      # nullable field.
      def update_settings(workspace_id, site_url: UNSET, topic: UNSET, audience: UNSET, language: UNSET,
                          location_code: UNSET, cadence_per_week: UNSET, review_hold_days: UNSET,
                          auto_publish: UNSET, image_tier: UNSET, in_body_images: UNSET, min_words: UNSET,
                          max_words: UNSET, brand_voice_id: UNSET, target_kind: UNSET,
                          target_account_id: UNSET, website_url: UNSET)
        body = compact_unset(
          'siteUrl' => site_url,
          'topic' => topic,
          'audience' => audience,
          'language' => language,
          'locationCode' => location_code,
          'cadencePerWeek' => cadence_per_week,
          'reviewHoldDays' => review_hold_days,
          'autoPublish' => auto_publish,
          'imageTier' => image_tier,
          'inBodyImages' => in_body_images,
          'minWords' => min_words,
          'maxWords' => max_words,
          'brandVoiceId' => brand_voice_id,
          'targetKind' => target_kind,
          'targetAccountId' => target_account_id,
          'websiteUrl' => website_url
        )
        response = as_hash(http.patch('/blog/settings', { 'workspaceId' => workspace_id }.merge(body)))
        BlogSettingsUpdate.new('settings' => response['data'], 'websiteSecret' => response['websiteSecret'])
      end

      # Issue a new website secret; the old one stops verifying at once.
      # Returns the secret, shown this once.
      def rotate_website_secret(workspace_id)
        result = as_hash(unwrap(http.post('/blog/settings/website-secret', { 'workspaceId' => workspace_id })))
        result['websiteSecret'].to_s
      end

      # Send a signed `article.test` delivery to `website_url`. A site that
      # does not answer 2xx comes back as a 502 `Fopost::Error`.
      def test_website(workspace_id)
        BlogWebsiteTest.new(unwrap(http.post('/blog/settings/website-test', { 'workspaceId' => workspace_id })))
      end

      # ── Keywords ──────────────────────────────────────────────────

      # `status` takes one status or an array of them.
      def list_keywords(workspace_id, status: nil, limit: nil)
        params = { 'workspaceId' => workspace_id, 'status' => csv(status), 'limit' => limit }
        parse_list(BlogKeyword, unwrap(http.get('/blog/keywords', params)))
      end

      # Queue a planning run that fills the keyword list; it answers before the
      # run finishes. Needs `ai`.
      def plan_keywords(workspace_id, seeds: nil)
        body = compact_nil('workspaceId' => workspace_id, 'seeds' => seeds)
        as_hash(unwrap(http.post('/blog/keywords/plan', body)))
      end

      # `planned_for` is a date, YYYY-MM-DD.
      def add_keyword(workspace_id, keyword:, planned_for: nil)
        body = compact_nil('workspaceId' => workspace_id, 'keyword' => keyword, 'plannedFor' => date(planned_for))
        BlogKeyword.new(unwrap(http.post('/blog/keywords', body)))
      end

      # Partial update. `planned_for: nil` takes the keyword off the calendar.
      def update_keyword(workspace_id, keyword_id, status: UNSET, planned_for: UNSET)
        body = compact_unset('status' => status, 'plannedFor' => UNSET.equal?(planned_for) ? UNSET : date(planned_for))
        BlogKeyword.new(unwrap(patch("/blog/keywords/#{keyword_id}", workspace_id, body)))
      end

      def delete_keyword(workspace_id, keyword_id)
        http.request(:delete, "/blog/keywords/#{keyword_id}", params: workspace(workspace_id))
        nil
      end

      # ── Articles ──────────────────────────────────────────────────

      # `status` takes one status or an array of them.
      def list_articles(workspace_id, status: nil, limit: nil)
        params = { 'workspaceId' => workspace_id, 'status' => csv(status), 'limit' => limit }
        parse_list(BlogArticle, unwrap(http.get('/blog/articles', params)))
      end

      # Queue an article. Give one of `title`, `keyword` or `keyword_id` (a
      # keyword from the plan). The article comes back `queued`; poll
      # {#get_article} or wait for the `article.published` webhook. Needs `ai`.
      def request_article(workspace_id, title: nil, keyword: nil, keyword_id: nil, instructions: nil)
        body = compact_nil(
          'workspaceId' => workspace_id,
          'title' => title,
          'keyword' => keyword,
          'keywordId' => keyword_id,
          'instructions' => instructions
        )
        BlogArticle.new(unwrap(http.post('/blog/articles', body)))
      end

      def get_article(workspace_id, article_id)
        BlogArticleFull.new(unwrap(http.get("/blog/articles/#{article_id}", workspace(workspace_id))))
      end

      # Partial update. Only a draft or scheduled article can be edited; any
      # other state answers 409. `publish_at` puts the draft on the calendar,
      # `publish_at: nil` returns it to review.
      def update_article(workspace_id, article_id, title: UNSET, slug: UNSET, excerpt: UNSET, meta_title: UNSET,
                         meta_description: UNSET, body_markdown: UNSET, tags: UNSET, publish_at: UNSET)
        body = compact_unset(
          'title' => title,
          'slug' => slug,
          'excerpt' => excerpt,
          'metaTitle' => meta_title,
          'metaDescription' => meta_description,
          'bodyMarkdown' => body_markdown,
          'tags' => tags,
          'publishAt' => UNSET.equal?(publish_at) ? UNSET : iso8601(publish_at)
        )
        BlogArticleFull.new(unwrap(patch("/blog/articles/#{article_id}", workspace_id, body)))
      end

      # Write it again from the same brief. Needs `ai`.
      def regenerate_article(workspace_id, article_id)
        BlogArticle.new(unwrap(http.request(:post, "/blog/articles/#{article_id}/regenerate",
                                            params: workspace(workspace_id))))
      end

      # Publish to the configured target. Needs `publish`; answers 409
      # `no_target` when the settings name nowhere to publish.
      def publish_article(workspace_id, article_id)
        BlogArticle.new(unwrap(http.request(:post, "/blog/articles/#{article_id}/publish",
                                            params: workspace(workspace_id))))
      end

      def reject_article(workspace_id, article_id)
        BlogArticle.new(unwrap(http.request(:post, "/blog/articles/#{article_id}/reject",
                                            params: workspace(workspace_id))))
      end

      def delete_article(workspace_id, article_id)
        http.request(:delete, "/blog/articles/#{article_id}", params: workspace(workspace_id))
        nil
      end

      private

      def workspace(workspace_id)
        { 'workspaceId' => workspace_id }
      end

      def patch(path, workspace_id, body)
        http.request(:patch, path, json: body, params: workspace(workspace_id))
      end

      def csv(value)
        value.is_a?(Array) ? value.join(',') : value
      end

      def date(value)
        value.respond_to?(:strftime) ? value.strftime('%Y-%m-%d') : value
      end
    end
  end
end
