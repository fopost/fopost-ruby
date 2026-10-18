# Changelog

All notable changes to this gem are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the gem follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.4.0] - 2026-10-18

### Added

- `queue` resource for the posting queue: `slots`, `create_slot`, `update_slot`, `delete_slot`,
  `next` and `preview` (`posts` scope), with the `QueueSlot`, `QueueSlotUpdated`,
  `QueueSlotDeleted` and `QueueSlotMove` models. `posts.create` and `posts.update` take
  `schedule: 'queue'` to land the post in the next free slot.
- `posts.unpublish` takes a published post down on every network (`publish` scope) and
  answers an `UnpublishResult`.
- `posts.validate_bulk_import` and `posts.commit_bulk_import` send a CSV as multipart and
  answer `BulkImportValidation` and `BulkImportResult`.
- `connect_sessions` resource: `create` and `get` for hosted connect links (`accounts`
  scope), with the `ConnectSession` model.
- `webhooks` resource (`Resources::WebhookEndpoints`, beside the unchanged
  `Fopost::Webhooks.verify`): `list`, `create`, `update`, `delete`, `test`, `deliveries`,
  `get_delivery` and `redeliver` (`webhooks` scope), with the `Webhook` and `WebhookDelivery`
  models.
- `automations` resource: `list`, `create`, `stats`, `get`, `update`, `delete`, `versions`,
  `get_version`, `restore_version`, `runs` and `get_run` (`automations` scope), with the
  `Automation`, `AutomationGraph`, `AutomationStats`, `AutomationVersion`,
  `AutomationRestoredVersion` and `AutomationRun` models.
- `logs.list` reads the API request log (`workspaces` scope) as a `RequestLogPage`.
- `workspaces.create`, `update` and `delete`; `Workspace` reads `connect_redirect_domains`
  and `updated_at`.
- `labels.create`, `get`, `update` and `delete`; `Label` reads `created_at` and `updated_at`.
- `accounts.list_communities`, `sync_communities`, `search_communities`, `add_community` and
  `remove_community` for X communities, with the `Community`, `CommunitySearchResult` and
  `CommunitySync` models.
- `analytics.overview`, `time_series`, `top_posts`, `labels`, `posts_table`, `posting_streak`,
  `demographics`, `inbox` and `collect`, each with its own model.
- `media.list`, `media.upload` (multipart through the API) and `media.delete`; `MediaItem`
  reads the library fields (`mime_type`, `tags`, `folder_id`, `brand_role`, `share`, ...).
- `OffsetPageMeta` for the lists that answer `page`, `per_page`, `total`, `total_pages`.

## [0.3.0] - 2026-10-18

### Added

- `inbox.like`, `unlike`, `pin`, `unpin`, `react`, `edit_comment`, `start_conversation` and
  `set_typing` (`inbox` scope, plus `publish`).
- `inbox.reply` takes `media_ids` and `quick_replies`; `text` is optional when `media_ids` is given.
- `InboxItem` reads `liked`, `pinned`, `reaction`, `edited_at` and the `can_like`, `can_pin`,
  `can_edit`, `can_react`, `can_send_media`, `can_quick_reply` and `can_private_reply` flags;
  `InboxAccount` reads `can_start_conversation`.
- `validate` resource: `post`, `length` and `media` preflight checks (`posts` scope).
- `account_groups` resource: `list`, `create`, `get`, `update`, `delete` and `set_members`
  (`accounts` scope).
- `accounts.update` renames an account and `accounts.move` moves it to another workspace;
  `accounts.list` takes `group_id`, and `SocialAccount#platform_name` is read.
- `posts.create` takes `account_group_id`.
- `media.presign`, `complete` and `upload_direct` upload a file straight to storage instead of
  through the API (`posts` scope).
- `ads` campaign tree: `account_tree`, and create, get, update, delete and duplicate for
  campaigns, ad sets and network ads, plus `bulk_set_status` (`ads` scope; writes also need
  `publish`).
- `ads` creatives (`creatives`, `create_creative`, `get_creative`, `delete_creative`), audiences
  (`get_audience`, `update_audience`, `delete_audience`, `add_audience_users`), `estimate_reach`,
  `insights` and `ad_insights`.
- `ads` lead forms and leads: `get_lead_form`, `archive_lead_form`, `leads_feed` (cursor
  paginated), `lead_pages`, `subscribe_lead_page` and `unsubscribe_lead_page`.
- `ads.create` takes `url_tags`.
- `blog.suggest_seeds(workspace_id, seeds:, prompt:)` suggests about 10 search terms from the
  blog goal and topics (needs `ai`, 402 on an empty balance), and `blog.submit_article` moves a
  draft, failed or rejected article to `in_review` (needs `posts`, 409 otherwise).
- `BlogSettings#goal`, `#focus_topics`, `#avoid_topics` and `#plan_run` (`BlogPlanRun`: `status`,
  `error`, `added`, `finished_at`); `update_settings` takes `goal:`, `focus_topics:` and
  `avoid_topics:`. `BlogKeyword#fit_reason` says why a keyword serves the goal.
- `in_review` on `BLOG_ARTICLE_STATUSES`.
- `whatsapp` resource for a WhatsApp Business connection: the business profile
  (`profile`, `update_profile`, `request_display_name`, `set_username`), message
  templates including the platform's own library (`templates`, `create_template`,
  `import_template`, …), groups, blocking, commerce settings and flows
  (`create_flow`, `upload_flow_json`, `publish_flow`, `flow_responses`, …), plus
  `account_events`. All need the `accounts` scope.
- `whatsapp.create_sandbox_session` and `sandbox_sessions` invite a tester to the
  platform-owned WhatsApp test number. Inviting sends a template, so it needs the
  `publish` scope.
- `whatsapp` on `Fopost::PLATFORMS`.
- `client.blog`: articles for a website. Settings (`get_settings`, `update_settings`,
  `rotate_website_secret`, `test_website`), keywords (`list_keywords`, `plan_keywords`,
  `add_keyword`, `update_keyword`, `delete_keyword`) and articles (`list_articles`,
  `request_article`, `get_article`, `update_article`, `regenerate_article`, `publish_article`,
  `reject_article`, `delete_article`), with the `BlogSettings`, `BlogSettingsUpdate`,
  `BlogWebsiteTest`, `BlogKeyword`, `BlogArticle`, `BlogArticleFull` and `BlogArticleImage`
  models and the `BLOG_ARTICLE_STATUSES`, `BLOG_KEYWORD_STATUSES` and `BLOG_TARGET_KINDS`
  constants. Reads need `posts`; `plan_keywords`, `request_article` and `regenerate_article`
  need `ai` and answer 402 on an empty balance; `publish_article` needs `publish` and answers
  409 `no_target` with no target set.
- `Fopost::Webhooks.verify(raw_body, headers, secret)` checks the signature on any FoPost
  webhook over the raw bytes in constant time, preferring the timestamped signature (300 s
  tolerance) and falling back to the plain body signature only when no timestamp was sent.
  It returns a `WebhookEvent` (`event`, `data`, `timestamp`); `#article` types the
  `article.published` payload as `BlogArticlePublished`. A bad signature raises
  `Fopost::WebhookSignatureError`.

- `media.limits` reads the account's upload ceilings (`UploadLimits`: `max_file_bytes`,
  `multipart_max_file_bytes`, `max_files_per_upload`, `next_tier`, `allowed_types`).
- `posts.create` and `posts.update` take `files:` (paths, IOs, or
  `{ filename:, io:/data:, mime_type: }` hashes). Files at or under the multipart ceiling go
  in one multipart request; larger ones go through direct upload and are attached to the first
  block.
- `media.presign` and `upload_direct` take `folder_id`, `origin`, `brand_role`, `brand_voice_id`
  and `person_consent`; `size` may go up to the account's `max_file_bytes`, which
  `PresignedUpload#max_file_bytes` reports.
- `Fopost::FileTooLargeError` for a 413 `file_too_large`, with `max_file_bytes`, `file_bytes`
  and `upgrade_url`.

- `InboxItem#moderation_status` carries the platform's own state for a comment
  (`published`, `held`, `spam`, `rejected`), and `InboxAccount#reconnect_required`
  flags an account connected before the inbox asked for a permission it needs.
- `client.broadcasts`: one message into every conversation the workspace already has
  with a segment of its contacts. `list`, `get`, `create`, `update`, `delete`, `send`,
  `cancel`, `recipients`. Reading needs the `inbox` scope; `send` and `cancel` also need
  `publish`.
- `client.sequences`: a series of messages on a delay. `list`, `get`, `create`, `update`,
  `delete`, `enroll`, `unenroll`, `enrollments`. `enroll` and `unenroll` need `publish`.
- Both honour each network's messaging window server-side. Messenger and Instagram take a
  business-initiated message only within 24 hours of the contact's last one, so recipients
  outside it come back `skipped` with `skip_reason` `window_closed` and nothing is
  attempted — the number sent is often lower than the audience.

- `contacts` resource: the people behind the inbox. `list`, `get`, `create`, `update`,
  `delete`, `conversations` (the threads one person appears in), `import` (CSV), and
  `list_fields` / `create_field` / `update_field` / `delete_field` for the custom columns
  a workspace keeps. All need the `inbox` scope.
- `contacts.conversation_analytics` reads `/v1/analytics/inbox/conversations`: volume and
  median reply time per thread. Needs the `analytics` scope.
- `snapchat` added to `Fopost::PLATFORMS`.

- `accounts.create_telegram_connect_code`, `get_telegram_connect_status`, `get_telegram_bot_commands`,
  `set_telegram_bot_commands` and `delete_telegram_bot_commands` (`accounts` scope).
- Meta messaging settings on `accounts`: `get_ice_breakers`, `set_ice_breakers` and
  `delete_ice_breakers` (Facebook Pages and Instagram), plus `get_persistent_menu`,
  `set_persistent_menu`, `delete_persistent_menu`, `get_greeting`, `set_greeting` and
  `delete_greeting` (Facebook Pages). A network without a field answers 400.
- `accounts.get_webhook_subscription` reports whether the network is still delivering events
  for an account, and `resubscribe_webhook` puts a lapsed subscription back.
- `inbox.handover` passes a Messenger thread to another Meta app, or takes it back when no
  `app_id` is given (`inbox` scope, plus `publish`).
- `accounts.list_slack_channels`, `list_slack_members`, `get_slack_identity` and `update_slack_identity`
  (`accounts` scope), with the `SlackChannel`, `SlackMember` and `SlackIdentity` models.
- The Discord bot surface on `accounts` (`accounts` scope, plus `publish` for anything that
  posts): `list_discord_channels`, `switch_discord_channel`, `get_discord_identity`,
  `update_discord_identity`, `list_discord_pins`, `delete_discord_message`,
  `pin_discord_message`, `unpin_discord_message`, `crosspost_discord_message`,
  `create_discord_thread`, `send_discord_dm`, `list_discord_events`, `get_discord_event`,
  `create_discord_event`, `update_discord_event`, `delete_discord_event`,
  `list_discord_members`, `get_discord_member`, `list_discord_roles`, `create_discord_role`,
  `update_discord_role`, `delete_discord_role`, `add_discord_member_role` and
  `remove_discord_member_role`, with the `DiscordChannel`, `DiscordIdentity`,
  `DiscordMessage`, `DiscordMessageRef`, `DiscordThread`, `DiscordScheduledEvent`,
  `DiscordMember` and `DiscordRole` models. A webhook connection answers
  `409 webhook_connection`.
- `DiscordChannel#can_post` says whether the bot may actually post in a channel;
  a channel permission in Discord can shut it out. `switch_discord_channel` answers
  `409 channel_not_writable` for one.
- Per-network extras on `accounts`, all `accounts` scope: Pinterest boards
  (`list_pinterest_boards`, `create_pinterest_board`), YouTube playlists and captions
  (`list_youtube_playlists`, `create_youtube_playlist`, `set_default_youtube_playlist`,
  `list_youtube_captions`, `upload_youtube_captions`, `read_youtube_transcript`), Bluesky post
  languages (`get_bluesky_languages`, `set_bluesky_languages`), TikTok creator info
  (`get_tiktok_creator_info`), TikTok music and place search plus video lookup
  (`search_tiktok_music`, `search_tiktok_locations`, `lookup_tiktok_video`),
  Instagram audio, publishing limit and stories
  (`search_instagram_audio`, `get_instagram_publishing_limit`, `list_instagram_stories`,
  `get_instagram_story_insights`) and LinkedIn mentions (`search_linkedin_mentions`), with a
  model each.
- `accounts.list_reddit_subreddits`, `list_reddit_subreddit_rules`, `list_reddit_flairs` and
  `set_reddit_default_subreddit` (`accounts` scope): a Reddit account's destinations, a
  subreddit's rules and post flairs, and where posts go when one names no subreddit. With the
  `RedditSubreddit`, `RedditSubredditRule(s)`, `RedditFlair(s)` and `RedditDefaultSubreddit`
  models. An account connected before those permissions were asked for answers 409
  `reconnect_required`.
- `validate.subreddit` (`posts` scope), with the `SubredditCheck` model.
- `inbox.vote` (`inbox` and `publish`): up, down, or `'none'` to take an earlier vote back.
- `SocialAccount#reconnect_required`, and the inbox item's `vote` and `can_vote`.
- `client.blogs` reaches content a connected site already owns, by the platform's own ids:
  `list_blogs`, `list_articles`, `get_article`, `create_article`, `update_article`,
  `delete_article`, plus `list_products` and `update_product` for a Shopify store, with the
  `RemoteBlog`, `RemoteArticle` and `RemoteProduct` models. `update_article` changes the live
  article in place and never creates a second post. Reads need `posts`; the writes need `publish`.

### Changed

- `client.blog` matches the live API contract: the workspace travels as `workspace_id` on the
  query string, single objects are read bare and lists from `{ data }`, and every response is
  read in snake_case. `BlogWebsiteTest` now carries `http_status` (what the website answered)
  instead of `ok`, `status` and `error`; a failed test is still a 502 `Fopost::Error` with
  `http_status` on its body.
- `blog.plan_keywords` no longer fills the calendar: results land as `suggested` keywords, and
  `update_keyword(status: 'planned')` picks one and gives it the next free date.
- `blog.publish_article` and `update_article(publish_at:)` need an article in review (or already
  scheduled or failed); a draft answers 409 until it is submitted.
- `BlogSettings#review_hold_days` is now the number of days before its planned date that a
  picked keyword starts being written.

### Removed

- **Breaking:** `BlogSettings#auto_publish` and the `auto_publish:` keyword on
  `blog.update_settings`. Every article now goes through `submit_article` before it publishes.

## [0.2.0] - 2026-09-19

### Added

- `inbox` resource: list items, threads and conversations, unread count, accounts and
  platforms, mark a thread read, refresh, update state, reply, hide, unhide, delete, and the
  reply approvals (`inbox` scope).
- `ads` resource: ads, external ads, boostable posts, connections, sources, Meta authorization,
  boost, create, refresh, set status, delete, audiences, targeting search, lead forms and leads
  (`ads` scope; `boost`, `create`, `set_status` and `delete` also need `publish`).

## [0.1.0] - 2026-08-30

Initial release.

- `Fopost::Client` with `posts`, `accounts`, `workspaces`, `labels`, and `ai` resources.
- Defaults to the documented `https://api.fopost.com/v1` base URL.
- Automatic retry on `429`, honouring `Retry-After`.
- Typed error classes per status, all rescuable as `Fopost::Error`.
- Response models that accept either wire casing and keep unknown fields on `#raw`.
- A pluggable transport, so the HTTP stack can be swapped or stubbed.

[Unreleased]: https://github.com/fopost/fopost-ruby/compare/v0.4.0...HEAD
[0.4.0]: https://github.com/fopost/fopost-ruby/releases/tag/v0.4.0
[0.3.0]: https://github.com/fopost/fopost-ruby/releases/tag/v0.3.0
[0.2.0]: https://github.com/fopost/fopost-ruby/releases/tag/v0.2.0
[0.1.0]: https://github.com/fopost/fopost-ruby/releases/tag/v0.1.0
