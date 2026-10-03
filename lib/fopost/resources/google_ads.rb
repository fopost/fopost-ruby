# frozen_string_literal: true

module Fopost
  module Resources
    # `client.ads.google` — the Google Ads surface no other network has.
    #
    # Campaigns, ad groups, ads, audiences and insights are on `client.ads`
    # and dispatch by connection. What is here — keywords, assets, Performance
    # Max asset groups, Local Services leads, conversions and raw GAQL — is
    # Google only, and a connection on another network answers 400.
    #
    # Every method needs the `ads` scope; anything that changes what a live
    # account serves or bids also needs `publish`. `customer_id` is digits only
    # and has to name an account the connection's grant reaches.
    class GoogleAds < Base
      # ── Keywords ──

      # Keywords on the account, or on one ad group.
      def keywords(connection_id:, customer_id:, workspace_id: nil, ad_group_id: nil)
        parse_list(GoogleKeyword, unwrap(http.get(
                                           '/ads/google/keywords',
                                           params(connection_id, customer_id, workspace_id,
                                                  'ad_group_id' => ad_group_id)
                                         )))
      end

      # The new keyword's id. Needs `publish` as well as `ads`.
      def create_keyword(workspace_id:, connection_id:, customer_id:, ad_group_id:, text:, match_type:,
                         cpc_bid_minor: nil)
        body = scope(workspace_id, connection_id, customer_id).merge(compact_nil(
                                                                       'adGroupId' => ad_group_id,
                                                                       'text' => text,
                                                                       'matchType' => match_type,
                                                                       'cpcBidMinor' => cpc_bid_minor
                                                                     ))
        id_of(http.post('/ads/google/keywords', body))
      end

      # `status` is "active" or "paused". Needs `publish` as well as `ads`.
      def update_keyword(keyword_id, workspace_id:, connection_id:, customer_id:, status: nil, cpc_bid_minor: nil)
        body = scope(workspace_id, connection_id, customer_id).merge(compact_nil(
                                                                       'status' => status,
                                                                       'cpcBidMinor' => cpc_bid_minor
                                                                     ))
        id_of(http.request(:patch, "/ads/google/keywords/#{keyword_id}", json: body))
      end

      # Needs `publish` as well as `ads`.
      def delete_keyword(keyword_id, workspace_id:, connection_id:, customer_id:)
        http.request(:delete, "/ads/google/keywords/#{keyword_id}",
                     json: scope(workspace_id, connection_id, customer_id))
        nil
      end

      # Ideas from seed keywords, a landing page, or both.
      def keyword_ideas(workspace_id:, connection_id:, customer_id:, seeds: nil, url: nil, language_id: nil,
                        geo_target_ids: nil)
        body = scope(workspace_id, connection_id, customer_id).merge(compact_nil(
                                                                       'seeds' => seeds,
                                                                       'url' => url,
                                                                       'languageId' => language_id,
                                                                       'geoTargetIds' => geo_target_ids
                                                                     ))
        parse_list(GoogleKeywordIdea, unwrap(http.post('/ads/google/keyword-ideas', body)))
      end

      def keyword_metrics(workspace_id:, connection_id:, customer_id:, keywords:)
        body = scope(workspace_id, connection_id, customer_id).merge('keywords' => keywords)
        parse_list(GoogleKeywordIdea, unwrap(http.post('/ads/google/keyword-metrics', body)))
      end

      # What people actually searched, with the metrics each term earned.
      def search_terms(connection_id:, customer_id:, since:, until_date:, workspace_id: nil)
        parse_list(GoogleSearchTerm, unwrap(http.get(
                                              '/ads/google/search-terms',
                                              params(connection_id, customer_id, workspace_id,
                                                     'since' => since, 'until' => until_date)
                                            )))
      end

      # ── Bid strategies and ad schedule ──

      def bid_strategies(connection_id:, customer_id:, workspace_id: nil)
        parse_list(GoogleBidStrategy, unwrap(http.get(
                                               '/ads/google/bid-strategies',
                                               params(connection_id, customer_id, workspace_id)
                                             )))
      end

      # Needs `publish` as well as `ads`.
      def create_bid_strategy(workspace_id:, connection_id:, customer_id:, name:, type:, target_minor: nil)
        body = scope(workspace_id, connection_id, customer_id).merge(compact_nil(
                                                                       'name' => name,
                                                                       'type' => type,
                                                                       'targetMinor' => target_minor
                                                                     ))
        id_of(http.post('/ads/google/bid-strategies', body))
      end

      def ad_schedule(connection_id:, customer_id:, campaign_id:, workspace_id: nil)
        parse_list(GoogleAdScheduleSlot, unwrap(http.get(
                                                  '/ads/google/ad-schedule',
                                                  params(connection_id, customer_id, workspace_id,
                                                         'campaign_id' => campaign_id)
                                                )))
      end

      # Replaces every slot on the campaign: Google has no partial edit for a
      # schedule. Needs `publish` as well as `ads`.
      def set_ad_schedule(workspace_id:, connection_id:, customer_id:, campaign_id:, slots:)
        body = scope(workspace_id, connection_id, customer_id).merge('campaignId' => campaign_id, 'slots' => slots)
        result = unwrap(http.request(:put, '/ads/google/ad-schedule', json: body))
        result.is_a?(Hash) ? result['slots'].to_i : 0
      end

      # ── Negative keyword lists ──

      def negative_keyword_lists(connection_id:, customer_id:, workspace_id: nil)
        parse_list(GoogleSharedSet, unwrap(http.get(
                                             '/ads/google/negative-keywords',
                                             params(connection_id, customer_id, workspace_id)
                                           )))
      end

      # Needs `publish` as well as `ads`.
      def create_negative_keyword_list(workspace_id:, connection_id:, customer_id:, name:)
        body = scope(workspace_id, connection_id, customer_id).merge('name' => name)
        id_of(http.post('/ads/google/negative-keywords', body))
      end

      # How many were added. Needs `publish` as well as `ads`.
      def add_negative_keywords(workspace_id:, connection_id:, customer_id:, shared_set_id:, keywords:)
        body = scope(workspace_id, connection_id, customer_id).merge(
          'sharedSetId' => shared_set_id, 'keywords' => keywords
        )
        result = unwrap(http.post('/ads/google/negative-keywords/keywords', body))
        result.is_a?(Hash) ? result['added'].to_i : 0
      end

      # Needs `publish` as well as `ads`.
      def attach_negative_keyword_list(workspace_id:, connection_id:, customer_id:, shared_set_id:, campaign_id:)
        body = scope(workspace_id, connection_id, customer_id).merge(
          'sharedSetId' => shared_set_id, 'campaignId' => campaign_id
        )
        http.post('/ads/google/negative-keywords/attach', body)
        nil
      end

      # ── Assets ──

      # Returns `{ assets: [...], links: [...] }`; an asset with no links is in
      # the library and serving nowhere.
      def assets(connection_id:, customer_id:, workspace_id: nil)
        result = unwrap(http.get('/ads/google/assets', params(connection_id, customer_id, workspace_id)))
        result = {} unless result.is_a?(Hash)
        {
          assets: parse_list(GoogleAsset, result['assets']),
          links: parse_list(GoogleAssetLink, result['links'])
        }
      end

      # `spec` is a sitelink, callout or snippet. Needs `publish` as well as `ads`.
      def create_asset(workspace_id:, connection_id:, customer_id:, spec:)
        body = scope(workspace_id, connection_id, customer_id).merge('spec' => spec)
        id_of(http.post('/ads/google/assets', body))
      end

      # Attaches to the account when `campaign_id` is left out. Needs `publish`.
      def attach_asset(workspace_id:, connection_id:, customer_id:, asset_id:, field_type:, campaign_id: nil)
        body = scope(workspace_id, connection_id, customer_id).merge(compact_nil(
                                                                       'assetId' => asset_id,
                                                                       'fieldType' => field_type,
                                                                       'campaignId' => campaign_id
                                                                     ))
        http.post('/ads/google/assets/attach', body)
        nil
      end

      # Removes the links that put it under an ad; on Google the asset itself
      # is permanent. Needs `publish` as well as `ads`.
      def delete_asset(asset_id, workspace_id:, connection_id:, customer_id:)
        http.request(:delete, "/ads/google/assets/#{asset_id}",
                     json: scope(workspace_id, connection_id, customer_id))
        nil
      end

      # ── Performance Max asset groups ──

      def asset_groups(connection_id:, customer_id:, workspace_id: nil, campaign_id: nil)
        parse_list(GoogleAssetGroup, unwrap(http.get(
                                              '/ads/google/asset-groups',
                                              params(connection_id, customer_id, workspace_id,
                                                     'campaign_id' => campaign_id)
                                            )))
      end

      # Starts paused unless `status` says otherwise. Needs `publish`.
      def create_asset_group(workspace_id:, connection_id:, customer_id:, campaign_id:, name:, final_urls:,
                             status: nil)
        body = scope(workspace_id, connection_id, customer_id).merge(compact_nil(
                                                                       'campaignId' => campaign_id,
                                                                       'name' => name,
                                                                       'finalUrls' => final_urls,
                                                                       'status' => status
                                                                     ))
        id_of(http.post('/ads/google/asset-groups', body))
      end

      # Needs `publish` as well as `ads`.
      def update_asset_group(asset_group_id, workspace_id:, connection_id:, customer_id:, name: nil, status: nil)
        body = scope(workspace_id, connection_id, customer_id).merge(compact_nil(
                                                                       'name' => name,
                                                                       'status' => status
                                                                     ))
        id_of(http.request(:patch, "/ads/google/asset-groups/#{asset_group_id}", json: body))
      end

      # Needs `publish` as well as `ads`.
      def delete_asset_group(asset_group_id, workspace_id:, connection_id:, customer_id:)
        http.request(:delete, "/ads/google/asset-groups/#{asset_group_id}",
                     json: scope(workspace_id, connection_id, customer_id))
        nil
      end

      # ── Local Services leads ──

      # Read live on every call and never stored by FoPost.
      def local_services_leads(connection_id:, customer_id:, since:, until_date:, workspace_id: nil)
        parse_list(GoogleLocalServicesLead, unwrap(http.get(
                                                     '/ads/google/local-services',
                                                     params(connection_id, customer_id, workspace_id,
                                                            'since' => since, 'until' => until_date)
                                                   )))
      end

      # ── Conversions ──

      def conversion_actions(connection_id:, customer_id:, workspace_id: nil)
        parse_list(GoogleConversionAction, unwrap(http.get(
                                                    '/ads/google/conversions',
                                                    params(connection_id, customer_id, workspace_id)
                                                  )))
      end

      # Needs `publish` as well as `ads`.
      def create_conversion_action(workspace_id:, connection_id:, customer_id:, name:, category:, value_minor: nil,
                                   counting_type: nil)
        body = scope(workspace_id, connection_id, customer_id).merge(compact_nil(
                                                                       'name' => name,
                                                                       'category' => category,
                                                                       'valueMinor' => value_minor,
                                                                       'countingType' => counting_type
                                                                     ))
        id_of(http.post('/ads/google/conversions', body))
      end

      # Offline conversions, matched to a click. Needs `publish` as well as `ads`.
      def upload_conversions(workspace_id:, connection_id:, customer_id:, conversions:)
        body = scope(workspace_id, connection_id, customer_id).merge('conversions' => conversions)
        uploaded(http.post('/ads/google/conversions/upload', body))
      end

      # Needs `publish` as well as `ads`.
      def upload_conversion_adjustments(workspace_id:, connection_id:, customer_id:, adjustments:)
        body = scope(workspace_id, connection_id, customer_id).merge('adjustments' => adjustments)
        uploaded(http.post('/ads/google/conversions/adjustments', body))
      end

      # ── GAQL ──

      # A read-only GAQL SELECT; rows come back exactly as Google returns them.
      def query(connection_id:, customer_id:, query:, workspace_id: nil)
        body = compact_nil(
          'workspaceId' => workspace_id,
          'connectionId' => connection_id,
          'customerId' => customer_id,
          'query' => query
        )
        result = unwrap(http.post('/ads/insights/query', body))
        rows = result.is_a?(Hash) ? result['rows'] : nil
        rows.is_a?(Array) ? rows : []
      end

      private

      def scope(workspace_id, connection_id, customer_id)
        { 'workspaceId' => workspace_id, 'connectionId' => connection_id, 'customerId' => customer_id }
      end

      def params(connection_id, customer_id, workspace_id, extra = {})
        compact_nil({
          'workspace_id' => workspace_id,
          'connection_id' => connection_id,
          'customer_id' => customer_id
        }.merge(extra))
      end

      def id_of(body)
        result = unwrap(body)
        result.is_a?(Hash) && result['id'] ? result['id'].to_s : ''
      end

      def uploaded(body)
        result = unwrap(body)
        result.is_a?(Hash) ? result['uploaded'].to_i : 0
      end
    end
  end
end
