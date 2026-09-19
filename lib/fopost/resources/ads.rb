# frozen_string_literal: true

module Fopost
  module Resources
    # `client.ads` — Meta ads, audiences and lead forms.
    #
    # Every method needs the `ads` scope. {#boost}, {#create}, {#set_status}
    # and {#delete} spend money and also need `publish`.
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

      # The Meta login URL; the caller finishes it in their own browser.
      # `method` is "business" (default) or "user".
      def authorize_meta(workspace_id:, method: nil, return_to: nil)
        body = compact_nil('workspaceId' => workspace_id, 'method' => method, 'returnTo' => return_to)
        result = unwrap(http.post('/ads/connections/meta/authorize', body))
        url = result.is_a?(Hash) ? result['url'] : nil
        url.nil? ? '' : url.to_s
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
                 text:, headline: nil, destination_url: nil, media_url: nil, paused: nil)
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

      private

      def stringify(hash)
        hash.to_h.transform_keys(&:to_s)
      end
    end
  end
end
