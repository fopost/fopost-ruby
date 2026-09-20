# frozen_string_literal: true

require 'fopost/http/client'
require 'fopost/models'
require 'fopost/resources/base'
require 'fopost/resources/account_groups'
require 'fopost/resources/accounts'
require 'fopost/resources/ads'
require 'fopost/resources/ai'
require 'fopost/resources/broadcasts'
require 'fopost/resources/contacts'
require 'fopost/resources/inbox'
require 'fopost/resources/labels'
require 'fopost/resources/media'
require 'fopost/resources/posts'
require 'fopost/resources/validate'
require 'fopost/resources/workspaces'

module Fopost
  # Client for the FoPost API.
  #
  #   client = Fopost::Client.new(api_key: 'fp_...')
  #   accounts = client.accounts.list(workspace_id: '9b2f6c1e-...')
  #
  # The key falls back to the `FOPOST_API_KEY` environment variable. Requests
  # that come back 429 are retried up to `max_retries` attempts, waiting for the
  # interval the API asks for in `Retry-After`.
  class Client
    DEFAULT_BASE_URL = HTTP::Client::DEFAULT_BASE_URL

    attr_reader :posts, :accounts, :account_groups, :workspaces, :labels, :ai, :inbox, :contacts,
                :broadcasts, :sequences, :ads, :validate, :media

    def initialize(api_key: nil, base_url: DEFAULT_BASE_URL, timeout: HTTP::Client::DEFAULT_TIMEOUT,
                   max_retries: HTTP::Client::DEFAULT_MAX_RETRIES, transport: nil, sleeper: nil)
      key = api_key || ENV['FOPOST_API_KEY']
      if key.nil? || key.to_s.empty?
        raise ConfigurationError,
              'fopost: an api key is required — pass api_key: or set FOPOST_API_KEY'
      end

      @http = HTTP::Client.new(
        api_key: key,
        base_url: base_url,
        timeout: timeout,
        max_retries: max_retries,
        transport: transport,
        sleeper: sleeper
      )

      @posts = Resources::Posts.new(@http)
      @accounts = Resources::Accounts.new(@http)
      @account_groups = Resources::AccountGroups.new(@http)
      @workspaces = Resources::Workspaces.new(@http)
      @labels = Resources::Labels.new(@http)
      @ai = Resources::Ai.new(@http)
      @inbox = Resources::Inbox.new(@http)
      @contacts = Resources::Contacts.new(@http)
      @broadcasts = Resources::Broadcasts.new(@http)
      @sequences = Resources::Sequences.new(@http)
      @ads = Resources::Ads.new(@http)
      @validate = Resources::Validate.new(@http)
      @media = Resources::Media.new(@http)
    end

    def base_url
      @http.base_url
    end

    # Call an endpoint the SDK does not wrap yet. Returns the decoded body.
    def request(method, path, json: nil, params: nil)
      @http.request(method, path, json: json, params: params)
    end

    def inspect
      "#<Fopost::Client base_url=#{base_url.inspect}>"
    end
  end
end
