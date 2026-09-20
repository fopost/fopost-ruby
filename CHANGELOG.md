# Changelog

All notable changes to this gem are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the gem follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

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

## [0.3.0] - 2026-09-19

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

[Unreleased]: https://github.com/fopost/fopost-ruby/compare/v0.3.0...HEAD
[0.3.0]: https://github.com/fopost/fopost-ruby/releases/tag/v0.3.0
[0.2.0]: https://github.com/fopost/fopost-ruby/releases/tag/v0.2.0
[0.1.0]: https://github.com/fopost/fopost-ruby/releases/tag/v0.1.0
