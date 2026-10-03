# frozen_string_literal: true

require 'fopost/resources/base'

module Fopost
  module Resources
    # `client.google_business` — manage a connected Google Business Profile location.
    #
    # Google grants Business Profile API access per project. Until that grant
    # lands on a deployment every call here raises a 503 configuration_error.
    #
    # Responses relay Google's own shape, field for field, so they come back as
    # plain hashes rather than models we would have to keep chasing.
    class GoogleBusiness < Base
      # The set fetched when a caller names no metrics.
      DEFAULT_DAILY_METRICS = %w[
        BUSINESS_IMPRESSIONS_DESKTOP_MAPS
        BUSINESS_IMPRESSIONS_DESKTOP_SEARCH
        BUSINESS_IMPRESSIONS_MOBILE_MAPS
        BUSINESS_IMPRESSIONS_MOBILE_SEARCH
        CALL_CLICKS
        WEBSITE_CLICKS
        BUSINESS_DIRECTION_REQUESTS
      ].freeze

      def get_location(account_id)
        as_hash(unwrap(http.get("/accounts/#{account_id}/gbp/location")))
      end

      # Patch the profile; an omitted keyword keeps a field, nil clears it.
      def update_location(account_id, title: UNSET, description: UNSET, website_uri: UNSET,
                          primary_phone: UNSET, additional_phones: UNSET, store_code: UNSET,
                          regular_hours: UNSET)
        body = compact_unset({
                               'title' => title,
                               'description' => description,
                               'website_uri' => website_uri,
                               'primary_phone' => primary_phone,
                               'additional_phones' => additional_phones,
                               'store_code' => store_code,
                               'regular_hours' => regular_hours
                             })
        as_hash(unwrap(http.request(:patch, "/accounts/#{account_id}/gbp/location", json: body)))
      end

      # The attribute values set on the location, or what Google offers it.
      def get_attributes(account_id, available: nil, category_name: nil, region_code: nil, language_code: nil)
        params = compact_nil({
                               'available' => available,
                               'category_name' => category_name,
                               'region_code' => region_code,
                               'language_code' => language_code
                             })
        as_hash(unwrap(http.get("/accounts/#{account_id}/gbp/attributes", params)))
      end

      # Only the named attributes change; every other one is left alone.
      def update_attributes(account_id, attributes)
        body = { 'attributes' => attributes }
        as_hash(unwrap(http.request(:patch, "/accounts/#{account_id}/gbp/attributes", json: body)))
      end

      def get_menus(account_id)
        as_hash(unwrap(http.get("/accounts/#{account_id}/gbp/menus")))
      end

      # Google has no per-section patch, so the whole menu set is replaced.
      def replace_menus(account_id, menus)
        as_hash(unwrap(http.put("/accounts/#{account_id}/gbp/menus", { 'menus' => menus })))
      end

      def get_services(account_id)
        as_hash(unwrap(http.get("/accounts/#{account_id}/gbp/services")))
      end

      def replace_services(account_id, service_items)
        as_hash(unwrap(http.put("/accounts/#{account_id}/gbp/services", { 'service_items' => service_items })))
      end

      def list_media(account_id, page_size: nil, page_token: nil)
        params = compact_nil({ 'page_size' => page_size, 'page_token' => page_token })
        as_hash(unwrap(http.get("/accounts/#{account_id}/gbp/media", params)))
      end

      # Add a photo from the media library; JPEG or PNG, same workspace.
      def add_media(account_id, media_id:, category: 'ADDITIONAL', description: nil)
        body = compact_nil({ 'media_id' => media_id, 'category' => category, 'description' => description })
        as_hash(unwrap(http.post("/accounts/#{account_id}/gbp/media", body)))
      end

      def delete_media(account_id, media_key)
        as_hash(unwrap(http.delete("/accounts/#{account_id}/gbp/media/#{media_key}")))
      end

      def list_place_actions(account_id)
        as_hash(unwrap(http.get("/accounts/#{account_id}/gbp/place-actions")))
      end

      def create_place_action(account_id, uri:, place_action_type:, is_preferred: nil)
        body = compact_nil({ 'uri' => uri, 'place_action_type' => place_action_type,
                             'is_preferred' => is_preferred })
        as_hash(unwrap(http.post("/accounts/#{account_id}/gbp/place-actions", body)))
      end

      def update_place_action(account_id, link_id, uri: UNSET, is_preferred: UNSET)
        body = compact_unset({ 'uri' => uri, 'is_preferred' => is_preferred })
        as_hash(unwrap(http.request(:patch, "/accounts/#{account_id}/gbp/place-actions/#{link_id}", json: body)))
      end

      def delete_place_action(account_id, link_id)
        as_hash(unwrap(http.delete("/accounts/#{account_id}/gbp/place-actions/#{link_id}")))
      end

      # The ways Google will let this location be verified.
      def get_verification_options(account_id, language_code: nil)
        params = compact_nil({ 'language_code' => language_code })
        as_hash(unwrap(http.get("/accounts/#{account_id}/gbp/verification", params)))
      end

      # The response names the pending verification to complete with the PIN.
      def start_verification(account_id, method:, language_code: nil, phone_number: nil,
                             email_address: nil, mailer_contact_name: nil)
        body = compact_nil({
                             'method' => method,
                             'language_code' => language_code,
                             'phone_number' => phone_number,
                             'email_address' => email_address,
                             'mailer_contact_name' => mailer_contact_name
                           })
        as_hash(unwrap(http.post("/accounts/#{account_id}/gbp/verification/start", body)))
      end

      def complete_verification(account_id, verification_name:, pin:)
        body = { 'verification_name' => verification_name, 'pin' => pin }
        as_hash(unwrap(http.post("/accounts/#{account_id}/gbp/verification/complete", body)))
      end

      # Daily impressions, calls, direction requests and clicks for the range.
      def get_performance(account_id, start_date:, end_date:, daily_metrics: nil)
        params = compact_nil({
                               'start_date' => start_date,
                               'end_date' => end_date,
                               'daily_metrics' => daily_metrics
                             })
        as_hash(unwrap(http.get("/accounts/#{account_id}/gbp/performance", params)))
      end

      # The search terms people used to find the listing, by month.
      def get_search_keywords(account_id, start_date:, end_date:, page_token: nil)
        params = compact_nil({
                               'keywords' => true,
                               'start_date' => start_date,
                               'end_date' => end_date,
                               'page_token' => page_token
                             })
        as_hash(unwrap(http.get("/accounts/#{account_id}/gbp/performance", params)))
      end

      # Hand the location to another workspace; the caller must own both.
      def assign(account_id, workspace_id:)
        AccountMove.new(unwrap(http.post("/accounts/#{account_id}/gbp/assign",
                                         { 'workspace_id' => workspace_id })))
      end
    end
  end
end
