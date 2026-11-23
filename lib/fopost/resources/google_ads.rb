# frozen_string_literal: true

module Fopost
  module Resources
    # `client.ads.google` — the Google Ads surface no other network has.
    #
    # Audiences and insights are on `client.ads` and dispatch by connection.
    # What is here (bid strategies, ad schedules, Local Services leads,
    # conversions and raw GAQL) is Google only, and a connection on another
    # network answers 400.
    #
    # Every method needs the `ads` scope; anything that changes what a live
    # account serves or bids also needs `publish`. `customer_id` is digits only
    # and has to name an account the connection's grant reaches.
    class GoogleAds < Base
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
        counted(body, 'uploaded')
      end

      def counted(body, key)
        result = unwrap(body)
        result.is_a?(Hash) ? result[key].to_i : 0
      end
    end
  end
end
