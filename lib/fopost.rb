# frozen_string_literal: true

require 'fopost/version'
require 'fopost/errors'
require 'fopost/unset'
require 'fopost/platforms'
require 'fopost/model'
require 'fopost/models'
require 'fopost/http/response'
require 'fopost/http/transport'
require 'fopost/http/net_http_transport'
require 'fopost/http/client'
require 'fopost/client'

# Official Ruby SDK for the FoPost API.
#
#   require 'fopost'
#
#   client = Fopost.new(api_key: 'fp_...')
#   workspace = client.workspaces.list.first
#   accounts = client.accounts.list(workspace_id: workspace.id)
#
#   post = client.posts.create(
#     workspace_id: workspace.id,
#     content: 'Hello from Ruby',
#     accounts: accounts.map(&:id)
#   )
#   client.posts.publish(post.id)
module Fopost
  DEFAULT_BASE_URL = Client::DEFAULT_BASE_URL

  # Shorthand for Fopost::Client.new.
  def self.new(**options)
    Client.new(**options)
  end
end
