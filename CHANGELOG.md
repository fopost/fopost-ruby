# Changelog

All notable changes to this gem are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the gem follows
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added

- `accounts.create_telegram_connect_code`, `get_telegram_connect_status`, `get_telegram_bot_commands`,
  `set_telegram_bot_commands` and `delete_telegram_bot_commands` (`accounts` scope).
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
