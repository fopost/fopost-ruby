# frozen_string_literal: true

module Fopost
  # Every platform the API can publish to. Model fields stay plain strings, so a
  # platform added server-side still parses on an older SDK.
  PLATFORMS = %w[
    twitter
    linkedin
    facebook
    instagram
    instagram-business
    telegram
    twitch
    discord
    slack
    reddit
    pinterest
    tumblr
    dribbble
    mewe
    tiktok
    youtube
    bluesky
    threads
    mastodon
    lemmy
    devto
    hashnode
    medium
    substack
    google-business
    kick
    listmonk
    wordpress
    nostr
    whop
    skool
  ].freeze

  POST_STATUSES = %w[
    draft
    pending_approval
    scheduled
    publishing
    published
    failed
    cancelled
  ].freeze
end
