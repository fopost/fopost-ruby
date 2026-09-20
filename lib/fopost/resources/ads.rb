# frozen_string_literal: true

module Fopost
  module Resources
    # `client.ads` — ads, audiences and lead forms across ad networks.
    #
    # Every method needs the `ads` scope. {#boost}, {#create}, {#set_status}
    # and {#delete} spend money and also need `publish`, as do the create,
    # update, delete and duplicate methods for campaigns, ad sets and network
    # ads, and {#bulk_set_status}.
    class Ads < Base
      # Boosts and ads created through FoPost, with insights from their last refresh.
      def list(workspace_id: nil)
        parse_list(Ad, unwrap(http.get('/ads', { 'workspace_id' => workspace_id })))
      end

      # Ads on the connected ad accounts that were made elsewhere. Read live, never stored.
      def external(workspace_id: nil)
        parse_list(ExternalAd, unwrap(http.get('/ads/external', { 'workspace_id' => workspace_id })))
      end

      def boostable(workspace_id: nil)
        parse_list(BoostablePost, unwrap(http.get('/ads/boostable', { 'workspace_id' => workspace_id })))
      end

      def connections(workspace_id: nil)
        parse_list(AdConnection, unwrap(http.get('/ads/connections', { 'workspace_id' => workspace_id })))
      end

      # Each connection with the ad accounts and Pages its grant reaches.
      def sources(workspace_id: nil)
        parse_list(AdSource, unwrap(http.get('/ads/sources', { 'workspace_id' => workspace_id })))
      end

      # The network's login URL; the caller finishes it in their own browser.
      # `provider` names the ad network and defaults to "meta"; `method` is the
      # network's own login method, "business" or "user" on Meta.
      def authorize(workspace_id:, provider: 'meta', method: nil, return_to: nil)
        body = compact_nil('workspaceId' => workspace_id, 'method' => method, 'returnTo' => return_to)
        result = unwrap(http.post("/ads/connections/#{provider}/authorize", body))
        url = result.is_a?(Hash) ? result['url'] : nil
        url.nil? ? '' : url.to_s
      end

      # Deprecated. Use `authorize`, which takes a provider.
      def authorize_meta(workspace_id:, method: nil, return_to: nil)
        authorize(workspace_id: workspace_id, method: method, return_to: return_to)
      end

      # Also deletes every ad record created through the connection.
      def delete_connection(connection_id, workspace_id:)
        http.request(:delete, "/ads/connections/#{connection_id}", params: { 'workspace_id' => workspace_id })
        nil
      end

      # Promote a post FoPost already published. Needs `ads` and `publish`.
      # The boost starts paused unless `paused: false`.
      def boost(workspace_id:, connection_id:, ad_account_id:, post_id:, account_id:, name:, goal:,
                budget:, targeting:, paused: nil)
        body = {
          'workspaceId' => workspace_id,
          'connectionId' => connection_id,
          'adAccountId' => ad_account_id,
          'postId' => post_id,
          'accountId' => account_id,
          'name' => name,
          'goal' => goal,
          'budget' => stringify(budget),
          'targeting' => stringify(targeting)
        }
        body['paused'] = paused unless paused.nil?
        Ad.new(unwrap(http.post('/ads/boost', body)))
      end

      # Create a standalone ad from a creative. Needs `ads` and `publish`.
      # The ad starts paused unless `paused: false`.
      def create(workspace_id:, connection_id:, ad_account_id:, page_id:, name:, goal:, budget:, targeting:,
                 text:, headline: nil, destination_url: nil, media_url: nil, url_tags: nil, paused: nil)
        body = {
          'workspaceId' => workspace_id,
          'connectionId' => connection_id,
          'adAccountId' => ad_account_id,
          'pageId' => page_id,
          'name' => name,
          'goal' => goal,
          'budget' => stringify(budget),
          'targeting' => stringify(targeting),
          'text' => text
        }
        body.merge!(
          compact_nil(
            'headline' => headline,
            'destinationUrl' => destination_url,
            'mediaUrl' => media_url,
            'urlTags' => url_tags,
            'paused' => paused
          )
        )
        Ad.new(unwrap(http.post('/ads', body)))
      end

      # Read the delivery status and lifetime insights from Meta.
      def refresh(ad_id, workspace_id:)
        Ad.new(unwrap(http.request(:post, "/ads/#{ad_id}/refresh", params: { 'workspace_id' => workspace_id })))
      end

      # `status` is "active" or "paused". Needs `ads` and `publish`.
      def set_status(ad_id, workspace_id:, status:)
        Ad.new(
          unwrap(
            http.request(:patch, "/ads/#{ad_id}", json: { 'status' => status },
                                                  params: { 'workspace_id' => workspace_id })
          )
        )
      end

      # End delivery and delete the ad on Meta as well as here. Needs `ads` and `publish`.
      def delete(ad_id, workspace_id:)
        http.request(:delete, "/ads/#{ad_id}", params: { 'workspace_id' => workspace_id })
        nil
      end

      def audiences(connection_id:, ad_account_id:, workspace_id: nil)
        AudiencesResult.new(
          unwrap(
            http.get(
              '/ads/audiences',
              { 'workspace_id' => workspace_id, 'connection_id' => connection_id, 'ad_account_id' => ad_account_id }
            )
          )
        )
      end

      # `spec` carries a `subtype` of CUSTOM, LOOKALIKE or WEBSITE. Answers `{ id, added }`.
      def create_audience(workspace_id:, connection_id:, ad_account_id:, name:, spec:, description: nil)
        body = {
          'workspaceId' => workspace_id,
          'connectionId' => connection_id,
          'adAccountId' => ad_account_id,
          'name' => name,
          'spec' => stringify(spec)
        }
        body['description'] = description unless description.nil?
        as_hash(unwrap(http.post('/ads/audiences', body)))
      end

      # Locations, interests, behaviours and income brackets as Meta names them.
      # `type` is country, region, city, zip, metro, interest, behavior or income.
      def search_targeting(connection_id:, type:, q: nil, workspace_id: nil)
        parse_list(
          TargetingOption,
          unwrap(
            http.get(
              '/ads/targeting/search',
              { 'workspace_id' => workspace_id, 'connection_id' => connection_id, 'type' => type, 'q' => q }
            )
          )
        )
      end

      def lead_forms(workspace_id: nil)
        parse_list(LeadFormSource, unwrap(http.get('/ads/lead-forms', { 'workspace_id' => workspace_id })))
      end

      # Create an Instant Form on the Page. Returns its id.
      def create_lead_form(workspace_id:, connection_id:, page_id:, name:, questions:, privacy_policy_url:,
                           thank_you_message:, follow_up_url: nil)
        body = {
          'workspaceId' => workspace_id,
          'connectionId' => connection_id,
          'pageId' => page_id,
          'name' => name,
          'questions' => questions.to_a,
          'privacyPolicyUrl' => privacy_policy_url,
          'thankYouMessage' => thank_you_message
        }
        body['followUpUrl'] = follow_up_url unless follow_up_url.nil?
        result = unwrap(http.post('/ads/lead-forms', body))
        id = result.is_a?(Hash) ? result['id'] : nil
        id.nil? ? '' : id.to_s
      end

      # One page of leads; pass `next_cursor` back as `after:` for the next.
      def leads(form_id, connection_id:, page_id:, after: nil, workspace_id: nil)
        LeadsPage.new(
          unwrap(
            http.get(
              "/ads/lead-forms/#{form_id}/leads",
              { 'workspace_id' => workspace_id, 'connection_id' => connection_id, 'page_id' => page_id,
                'after' => after }
            )
          )
        )
      end

      # Campaigns, ad sets and ads on one ad account, read live from Meta.
      def account_tree(ad_account_id, connection_id:, workspace_id: nil)
        AdAccountTree.new(
          unwrap(http.get("/ads/accounts/#{ad_account_id}/tree", meta_query(workspace_id, connection_id)))
        )
      end

      # `goal` is engagement, traffic, awareness or video_views. Starts paused
      # unless `paused: false`. Needs `ads` and `publish`.
      def create_campaign(workspace_id:, connection_id:, ad_account_id:, name:, goal:, paused: nil)
        body = {
          'workspaceId' => workspace_id,
          'connectionId' => connection_id,
          'adAccountId' => ad_account_id,
          'name' => name,
          'goal' => goal
        }
        body['paused'] = paused unless paused.nil?
        AdCampaign.new(unwrap(http.post('/ads/campaigns', body)))
      end

      def get_campaign(campaign_id, connection_id:, workspace_id: nil)
        AdCampaign.new(unwrap(http.get("/ads/campaigns/#{campaign_id}", meta_query(workspace_id, connection_id))))
      end

      # `status` is "active" or "paused". Needs `ads` and `publish`.
      def update_campaign(campaign_id, workspace_id:, connection_id:, name: nil, status: nil)
        AdCampaign.new(
          patch_object("/ads/campaigns/#{campaign_id}", workspace_id, connection_id,
                       'name' => name, 'status' => status)
        )
      end

      # Needs `ads` and `publish`.
      def delete_campaign(campaign_id, workspace_id:, connection_id:)
        delete_object("/ads/campaigns/#{campaign_id}", workspace_id, connection_id)
      end

      # Copy the campaign on Meta and return the copy's id. Needs `ads` and `publish`.
      def duplicate_campaign(campaign_id, workspace_id:, connection_id:, paused: nil)
        duplicate_object("/ads/campaigns/#{campaign_id}", workspace_id, connection_id, paused)
      end

      # `budget` is `{ minor:, type:, endAt: }`; `targeting` uses the API's camelCase keys.
      # Starts paused unless `paused: false`. Needs `ads` and `publish`.
      def create_ad_set(workspace_id:, connection_id:, campaign_id:, page_id:, name:, goal:, budget:, targeting:,
                        paused: nil)
        body = {
          'workspaceId' => workspace_id,
          'connectionId' => connection_id,
          'campaignId' => campaign_id,
          'pageId' => page_id,
          'name' => name,
          'goal' => goal,
          'budget' => stringify(budget),
          'targeting' => stringify(targeting)
        }
        body['paused'] = paused unless paused.nil?
        AdSet.new(unwrap(http.post('/ads/ad-sets', body)))
      end

      def get_ad_set(ad_set_id, connection_id:, workspace_id: nil)
        AdSet.new(unwrap(http.get("/ads/ad-sets/#{ad_set_id}", meta_query(workspace_id, connection_id))))
      end

      # Needs `ads` and `publish`.
      def update_ad_set(ad_set_id, workspace_id:, connection_id:, name: nil, status: nil, budget_minor: nil,
                        end_at: nil, targeting: nil)
        AdSet.new(
          patch_object(
            "/ads/ad-sets/#{ad_set_id}", workspace_id, connection_id,
            'name' => name, 'status' => status, 'budgetMinor' => budget_minor, 'endAt' => iso8601(end_at),
            'targeting' => targeting.nil? ? nil : stringify(targeting)
          )
        )
      end

      # Needs `ads` and `publish`.
      def delete_ad_set(ad_set_id, workspace_id:, connection_id:)
        delete_object("/ads/ad-sets/#{ad_set_id}", workspace_id, connection_id)
      end

      # Needs `ads` and `publish`.
      def duplicate_ad_set(ad_set_id, workspace_id:, connection_id:, paused: nil)
        duplicate_object("/ads/ad-sets/#{ad_set_id}", workspace_id, connection_id, paused)
      end

      # An ad inside an ad set, from an existing creative (unlike {#create}).
      # Starts paused unless `paused: false`. Needs `ads` and `publish`.
      def create_network_ad(workspace_id:, connection_id:, ad_set_id:, creative_id:, name:, paused: nil)
        body = {
          'workspaceId' => workspace_id,
          'connectionId' => connection_id,
          'adSetId' => ad_set_id,
          'creativeId' => creative_id,
          'name' => name
        }
        body['paused'] = paused unless paused.nil?
        NetworkAd.new(unwrap(http.post('/ads/ads', body)))
      end

      def get_network_ad(ad_id, connection_id:, workspace_id: nil)
        NetworkAd.new(unwrap(http.get("/ads/ads/#{ad_id}", meta_query(workspace_id, connection_id))))
      end

      # Needs `ads` and `publish`.
      def update_network_ad(ad_id, workspace_id:, connection_id:, name: nil, status: nil, creative_id: nil)
        NetworkAd.new(
          patch_object("/ads/ads/#{ad_id}", workspace_id, connection_id,
                       'name' => name, 'status' => status, 'creativeId' => creative_id)
        )
      end

      # Needs `ads` and `publish`.
      def delete_network_ad(ad_id, workspace_id:, connection_id:)
        delete_object("/ads/ads/#{ad_id}", workspace_id, connection_id)
      end

      # Needs `ads` and `publish`.
      def duplicate_network_ad(ad_id, workspace_id:, connection_id:, paused: nil)
        duplicate_object("/ads/ads/#{ad_id}", workspace_id, connection_id, paused)
      end

      # Pause or activate many objects at once. Each of `objects` is `{ id:, level: }`
      # with level campaign, ad_set or ad. Needs `ads` and `publish`.
      def bulk_set_status(workspace_id:, connection_id:, status:, objects:)
        body = {
          'workspaceId' => workspace_id,
          'connectionId' => connection_id,
          'status' => status,
          'objects' => objects.to_a.map { |object| stringify(object) }
        }
        parse_list(BulkAdStatusResult, unwrap(http.post('/ads/status', body)))
      end

      def creatives(connection_id:, ad_account_id:, workspace_id: nil)
        result = unwrap(
          http.get('/ads/creatives', meta_query(workspace_id, connection_id).merge('ad_account_id' => ad_account_id))
        )
        parse_list(AdCreative, result.is_a?(Hash) ? result['creatives'] : nil)
      end

      # `format` is image, video or carousel; a carousel takes `cards`
      # (`{ mediaUrl:, destinationUrl:, headline:, description: }`).
      def create_creative(workspace_id:, connection_id:, ad_account_id:, page_id:, name:, format:, text:,
                          headline: nil, destination_url: nil, call_to_action: nil, url_tags: nil, media_url: nil,
                          thumbnail_media_url: nil, cards: nil)
        body = {
          'workspaceId' => workspace_id,
          'connectionId' => connection_id,
          'adAccountId' => ad_account_id,
          'pageId' => page_id,
          'name' => name,
          'format' => format,
          'text' => text
        }
        body.merge!(
          compact_nil(
            'headline' => headline,
            'destinationUrl' => destination_url,
            'callToAction' => call_to_action,
            'urlTags' => url_tags,
            'mediaUrl' => media_url,
            'thumbnailMediaUrl' => thumbnail_media_url,
            'cards' => cards&.map { |card| stringify(card) }
          )
        )
        AdCreative.new(unwrap(http.post('/ads/creatives', body)))
      end

      def get_creative(creative_id, connection_id:, workspace_id: nil)
        AdCreative.new(unwrap(http.get("/ads/creatives/#{creative_id}", meta_query(workspace_id, connection_id))))
      end

      def delete_creative(creative_id, workspace_id:, connection_id:)
        delete_object("/ads/creatives/#{creative_id}", workspace_id, connection_id)
      end

      def get_audience(audience_id, connection_id:, workspace_id: nil)
        Audience.new(unwrap(http.get("/ads/audiences/#{audience_id}", meta_query(workspace_id, connection_id))))
      end

      def update_audience(audience_id, workspace_id:, connection_id:, name: nil, description: nil)
        Audience.new(
          patch_object("/ads/audiences/#{audience_id}", workspace_id, connection_id,
                       'name' => name, 'description' => description)
        )
      end

      def delete_audience(audience_id, workspace_id:, connection_id:)
        delete_object("/ads/audiences/#{audience_id}", workspace_id, connection_id)
      end

      # Add customers to a custom audience by email. Returns how many were sent to Meta.
      def add_audience_users(audience_id, workspace_id:, connection_id:, emails:)
        result = unwrap(
          http.request(:post, "/ads/audiences/#{audience_id}/users",
                       json: { 'emails' => emails.to_a }, params: meta_query(workspace_id, connection_id))
        )
        result.is_a?(Hash) ? result['added'].to_i : 0
      end

      def estimate_reach(workspace_id:, connection_id:, ad_account_id:, page_id:, targeting:)
        body = {
          'workspaceId' => workspace_id,
          'connectionId' => connection_id,
          'adAccountId' => ad_account_id,
          'pageId' => page_id,
          'targeting' => stringify(targeting)
        }
        ReachEstimate.new(unwrap(http.post('/ads/reach-estimate', body)))
      end

      # Insights for any campaign, ad set or ad id on Meta. `breakdown` is age,
      # gender, placement or country; `daily: true` adds a per-day timeline.
      def insights(connection_id:, object_id:, since:, until:, breakdown: nil, daily: nil, workspace_id: nil)
        until_date = binding.local_variable_get(:until)
        params = meta_query(workspace_id, connection_id).merge(
          'object_id' => object_id, **insights_query(since, until_date, breakdown, daily)
        )
        AdInsightsReport.new(unwrap(http.get('/ads/insights', params)))
      end

      # Insights for an ad created through FoPost, by its FoPost id.
      def ad_insights(ad_id, workspace_id:, since:, until:, breakdown: nil, daily: nil)
        until_date = binding.local_variable_get(:until)
        params = { 'workspace_id' => workspace_id, **insights_query(since, until_date, breakdown, daily) }
        AdInsightsReport.new(unwrap(http.get("/ads/#{ad_id}/insights", params)))
      end

      def get_lead_form(form_id, connection_id:, page_id:, workspace_id: nil)
        LeadFormDetail.new(
          unwrap(
            http.get("/ads/lead-forms/#{form_id}",
                     meta_query(workspace_id, connection_id).merge('page_id' => page_id))
          )
        )
      end

      def archive_lead_form(form_id, workspace_id:, connection_id:, page_id:)
        body = { 'workspaceId' => workspace_id, 'connectionId' => connection_id, 'pageId' => page_id }
        LeadFormDetail.new(unwrap(http.post("/ads/lead-forms/#{form_id}/archive", body)))
      end

      # Stored leads from subscribed Pages, newest first. Pass `next_cursor`
      # back as `cursor:` for the next page.
      def leads_feed(form_id: nil, page_id: nil, cursor: nil, limit: nil, workspace_id: nil)
        LeadsFeedPage.new(
          unwrap(
            http.get(
              '/ads/leads',
              { 'workspace_id' => workspace_id, 'form_id' => form_id, 'page_id' => page_id, 'cursor' => cursor,
                'limit' => limit }
            )
          )
        )
      end

      # Pages subscribed to lead delivery.
      def lead_pages(workspace_id: nil)
        parse_list(LeadPage, unwrap(http.get('/ads/lead-pages', { 'workspace_id' => workspace_id })))
      end

      # Subscribe a Page to lead delivery. Answers `{ "pageId", "backfilled" }`.
      def subscribe_lead_page(workspace_id:, connection_id:, page_id:)
        body = { 'workspaceId' => workspace_id, 'connectionId' => connection_id, 'pageId' => page_id }
        as_hash(unwrap(http.post('/ads/lead-pages', body)))
      end

      def unsubscribe_lead_page(page_id, workspace_id:, connection_id:)
        delete_object("/ads/lead-pages/#{page_id}", workspace_id, connection_id)
      end

      private

      def meta_query(workspace_id, connection_id)
        { 'workspace_id' => workspace_id, 'connection_id' => connection_id }
      end

      def insights_query(since, until_date, breakdown, daily)
        query = { 'since' => since.to_s, 'until' => until_date.to_s, 'breakdown' => breakdown }
        query['daily'] = daily.to_s unless daily.nil?
        query
      end

      def patch_object(path, workspace_id, connection_id, fields)
        unwrap(http.request(:patch, path, json: compact_nil(fields), params: meta_query(workspace_id, connection_id)))
      end

      def delete_object(path, workspace_id, connection_id)
        http.request(:delete, path, params: meta_query(workspace_id, connection_id))
        nil
      end

      # Answers the copy's Meta id.
      def duplicate_object(path, workspace_id, connection_id, paused)
        json = paused.nil? ? {} : { 'paused' => paused }
        result = unwrap(
          http.request(:post, "#{path}/duplicate", json: json, params: meta_query(workspace_id, connection_id))
        )
        id = result.is_a?(Hash) ? result['id'] : nil
        id.nil? ? '' : id.to_s
      end

      def stringify(hash)
        hash.to_h.transform_keys(&:to_s)
      end
    end
  end
end
