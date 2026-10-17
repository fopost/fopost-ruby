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
    snapchat
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
    whatsapp
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

  BLOG_ARTICLE_STATUSES = %w[
    queued
    writing
    draft
    scheduled
    publishing
    published
    failed
    rejected
  ].freeze

  BLOG_KEYWORD_STATUSES = %w[
    suggested
    planned
    written
    dismissed
  ].freeze

  BLOG_TARGET_KINDS = %w[
    product_blog
    account
    website
  ].freeze
end
