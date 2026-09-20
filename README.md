# FoPost Ruby SDK

[![Gem Version](https://img.shields.io/gem/v/fopost.svg)](https://rubygems.org/gems/fopost)
[![Downloads](https://img.shields.io/gem/dt/fopost.svg)](https://rubygems.org/gems/fopost)
[![CI](https://img.shields.io/github/actions/workflow/status/fopost/fopost-ruby/ci.yml?branch=main&label=ci)](https://github.com/fopost/fopost-ruby/actions)
[![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

The official Ruby SDK for the [FoPost](https://fopost.com) API. Connect social accounts once, then compose, schedule, and publish to +30 platforms from your own application.

Requires Ruby 3.1 or newer. No runtime dependencies: the gem talks over `net/http` from the standard library, so it drops into any app without a version conflict.

> **0.x release.** The public API is still settling and minor versions may contain breaking changes. Pin an exact version if that matters to you.

## Install

```bash
bundle add fopost
```

Or without Bundler:

```bash
gem install fopost
```

## Get an API key

Create a key at [fopost.com/dashboard/api-keys](https://fopost.com/dashboard/api-keys). The full API reference lives at [fopost.com/docs](https://fopost.com/docs).

## Quick start

```ruby
require 'fopost'

client = Fopost.new(api_key: 'fp_...') # or set FOPOST_API_KEY

workspace = client.workspaces.list.first
accounts = client.accounts.list(workspace_id: workspace.id)

post = client.posts.create(
  workspace_id: workspace.id,
  content: 'Hello from Ruby',
  accounts: accounts.map(&:id)
)

client.posts.publish(post.id)
```

`content` takes a string for a single block, or an array for a thread:

```ruby
client.posts.create(
  workspace_id: workspace.id,
  content: [
    'First post in the thread',
    {
      'text' => 'Second one, with an image',
      'media' => [{ 'type' => 'image', 'name' => 'chart.png', 'url' => 'https://.../chart.png' }]
    }
  ],
  accounts: accounts.map(&:id)
)
```

`accounts` takes account ids, the `Fopost::SocialAccount` objects themselves, or hashes with an `id`.

## Scheduling

`status` is `"draft"` or `"scheduled"`; a scheduled post needs `schedule_at`. To send something out now, create it and call `publish`.

```ruby
client.posts.create(
  workspace_id: workspace.id,
  status: 'scheduled',
  schedule_at: Time.utc(2026, 9, 1, 10, 0),
  content: 'Scheduled with the SDK',
  accounts: [accounts.first.id]
)
```

`schedule_at` accepts a `Time`, a `DateTime`, or an ISO 8601 string.

## Posts

```ruby
client.posts.get(post_id)
client.posts.update(post_id, title: 'Renamed')  # partial: only what you pass is sent
client.posts.delete(post_id)

client.posts.publish(post_id)     # queue delivery to every targeted account
client.posts.cancel(post_id)      # cancel what has not gone out yet
client.posts.retry(post_id)       # retry only the deliveries that failed
client.posts.preflight(post_id)   # per-account blockers, without publishing

client.posts.deliveries(post_id).each { |d| puts "#{d.platform}: #{d.status}" }
```

`update` is a partial update, so passing `nil` clears a field and leaving an argument out leaves it alone:

```ruby
client.posts.update(post_id, schedule_at: nil)   # sends {"schedule_at": null}
client.posts.update(post_id, title: 'Renamed')   # sends {"title": "Renamed"}
```

## Account groups

Name a set of accounts once and post to all of them. Needs the `accounts` scope.

```ruby
group = client.account_groups.create(workspace_id: workspace.id, name: 'Launch', account_ids: %w[acc_1 acc_2])
client.account_groups.list(workspace_id: workspace.id)
client.account_groups.update(group.id, name: 'Launch week')
client.account_groups.set_members(group.id, %w[acc_1 acc_3])   # replaces the members
client.account_groups.delete(group.id)

client.posts.create(workspace_id: workspace.id, content: 'Hello', account_group_id: group.id)
client.accounts.list(group_id: group.id)
```

Accounts can also be renamed and moved between workspaces you own:

```ruby
client.accounts.update(account_id, display_name: 'Brand HQ')   # nil restores the platform name
client.accounts.move(account_id, workspace_id: other_workspace.id)
```

Connect a Telegram chat with a one-time code, and set the command menu the bot shows there:

```ruby
code = client.accounts.create_telegram_connect_code(workspace_id: workspace.id)
puts code.command                                   # send this to the bot in the chat
client.accounts.get_telegram_connect_status(code.code).status   # pending, connected, failed or expired

client.accounts.set_telegram_bot_commands(account_id, [{ command: 'start', description: 'Start here' }])
client.accounts.get_telegram_bot_commands(account_id)
client.accounts.delete_telegram_bot_commands(account_id)
```

Read a Slack account's channels and members, and set the name and icon it posts under. A member's `id` is the
handle for `inbox.start_conversation`:

```ruby
client.accounts.list_slack_channels(account_id)
client.accounts.list_slack_members(account_id)
client.accounts.get_slack_identity(account_id)
client.accounts.update_slack_identity(account_id, username: 'Launch Bot', icon_emoji: ':rocket:')   # nil clears

# Meta messaging settings. Ice breakers on Facebook Pages and Instagram; the menu and
# greeting on Pages only. A network without a field answers 400.
client.accounts.set_ice_breakers(account_id, [{ question: 'What are your hours?', payload: 'HOURS' }])
client.accounts.set_persistent_menu(account_id, [{ locale: 'default',
                                                   call_to_actions: [{ type: 'postback', title: 'Talk to Us',
                                                                       payload: 'HUMAN' }] }])
client.accounts.set_greeting(account_id, [{ text: 'Hi! Ask us anything.' }])

# Is the network still delivering events for this account?
subscription = client.accounts.get_webhook_subscription(account_id)
client.accounts.resubscribe_webhook(account_id) unless subscription.subscribed
```

On a Discord bot connection, read and change the channel it posts to and manage the server itself:

```ruby
client.accounts.list_discord_channels(account_id)
client.accounts.switch_discord_channel(account_id, 'c2')
client.accounts.update_discord_identity(account_id, username: 'Release Bot')       # nil clears

client.accounts.create_discord_event(account_id, name: 'Launch stream',
                                                 start_time: '2026-10-01T18:00:00Z',
                                                 end_time: '2026-10-01T19:00:00Z',
                                                 location: 'https://yourbrand.com/live')

members = client.accounts.list_discord_members(account_id, query: 'ada')
role = client.accounts.create_discord_role(account_id, name: 'Beta')
client.accounts.add_discord_member_role(account_id, role.id, members[0].id)
client.accounts.send_discord_dm(account_id, members[0].id, 'Welcome aboard')
```

## Pagination

`posts.list` returns one page, which is `Enumerable` over its items. `posts.each` walks every page for you.

```ruby
page = client.posts.list(workspace_id: workspace.id, status: 'published', per_page: 50)
puts "#{page.meta.total} published posts"
page.each { |post| puts "#{post.id} #{post.status}" }

# Every post, one page fetched at a time
client.posts.each(workspace_id: workspace.id) { |post| puts post.id }

# Or page by page, when you want the meta
client.posts.each_page(workspace_id: workspace.id) do |p|
  puts "#{p.meta.current_page} (#{p.size} posts)"
end
```

Both walkers return an `Enumerator` when called without a block, so `client.posts.each(...).lazy.first(10)` works.

## AI features

```ruby
balance = client.ai.credits
puts "#{balance.credits_remaining} of #{balance.credits_total} credits left"

result = client.ai.generate_caption(
  current_caption: 'shipping a new feature',
  platforms: %w[twitter linkedin]
)
puts result.caption
```

`rewrite` and `repurpose_url` are wired the same way:

```ruby
rewrites = client.ai.rewrite(
  content: 'Long article-style draft...',
  platforms: %w[twitter linkedin bluesky]
)
rewrites.results.each { |variant| puts "#{variant.platform}: #{variant.content}" }

repurposed = client.ai.repurpose_url(
  url: 'https://example.com/blog/post',
  platforms: %w[twitter linkedin bluesky threads]
)
```

> **API keys reach `credits` and `generate_caption`.** `rewrite` and `repurpose_url` currently require a signed-in dashboard session and answer `401` to an API key. They are here so the surface is complete once the server opens them up.

## Validate

Check a draft before you create a post. Needs the `posts` scope; nothing is stored.

```ruby
result = client.validate.post(content: 'Hello', platforms: %w[twitter linkedin],
                              media: [{ url: 'https://example.com/a.png', mime_type: 'image/png' }])
result.platforms.reject(&:ready).each { |p| puts "#{p.platform}: #{p.issues.join(', ')}" }

lengths = client.validate.length(text: 'Hello', platforms: %w[twitter bluesky])
lengths.platforms.each { |p| puts "#{p.platform}: #{p.length}/#{p.limit || 'no limit'} #{p.unit}" }

file = client.validate.media(url: 'https://example.com/a.png')
puts file.ok ? file.type : file.issues.join(', ')
```

## Activity

What happened in a workspace, newest first. Needs the `analytics` scope.

```ruby
page = client.activity.list(workspace_id: workspace.id)
page.events.each { |event| puts "#{event.time} #{event.actor.name}: #{event.summary}" }
page.next_cursor  # pass back as cursor: for the next page
```

`kind: 'security'` is the audit log: members joining, leaving or changing role
and access, and changes to two-step verification, passkeys, single sign-on and
signed-in devices. Those rows are append-only and never expire.

```ruby
audit = client.activity.list(workspace_id: workspace.id, kind: 'security')
```

## Inbox

Comments, mentions and direct messages on connected accounts. Needs the `inbox` scope.

```ruby
page = client.inbox.list(workspace_id: workspace.id, state: 'unread', sort: 'unanswered')
page.each { |item| puts "#{item.platform} #{item.author_handle}: #{item.text}" }

client.inbox.threads(workspace_id: workspace.id)         # one row per post with comments
client.inbox.conversations(workspace_id: workspace.id)   # one row per DM thread
client.inbox.unread_count(workspace_id: workspace.id)

client.inbox.reply(item.id, text: 'Thanks!')
client.inbox.update(item.id, state: 'snoozed', snoozed_until: Time.utc(2026, 9, 20, 9))
client.inbox.hide(item.id)
client.inbox.mark_thread_read(workspace_id: workspace.id, account_id: item.account.id,
                              post_external_id: item.post_external_id)
client.inbox.refresh(workspace_id: workspace.id)

client.inbox.approvals(workspace_id: workspace.id).each { |a| client.inbox.approve_reply(a.id) }
```

Acting on the platform also needs the `publish` scope. Each item's `can_*` flags say which actions its network supports.

```ruby
client.inbox.like(item.id)                               # unlike, pin, unpin work the same way
client.inbox.react(item.id, reaction: '❤️')               # reaction: nil removes ours
client.inbox.edit_comment(item.id, text: 'Fixed a typo')
client.inbox.reply(item.id, media_ids: [media.id], quick_replies: %w[Yes No])
client.inbox.start_conversation(account_id: account.id, handle: 'jordanvale', text: 'Hi!')
client.inbox.start_conversation(comment_id: item.id, text: 'Sent you the details')
client.inbox.set_typing(item.conversation_id, account_id: item.account.id)

# Messenger hand-over: pass the thread to another Meta app, or take it back with no app id.
client.inbox.handover(item.conversation_id, account_id: item.account.id, app_id: '263902037430900')
client.inbox.handover(item.conversation_id, account_id: item.account.id)
```

## Contacts

The people behind the inbox. A contact is one human however many handles they write from: an inbound item files its author, a reply files whoever you answered, and both fold into whatever is already on file. Needs the `inbox` scope.

```ruby
page = client.contacts.list(workspace_id: workspace_id, search: 'ada')
page.each { |contact| puts "#{contact.display_name} — #{contact.channels.size} handles" }
puts page.meta.total

contact = client.contacts.get(contact_id)

# Folds into whoever already holds the first channel, so this cannot duplicate someone.
contact = client.contacts.create(
  workspace_id: workspace_id,
  channels: [{ 'platform' => 'x', 'handle' => 'ada_writes' }],
  display_name: 'Ada Okafor',
  fields: { 'plan_tier' => 'Pro' }
)

client.contacts.update(contact.id, fields: { 'region' => nil })  # nil clears a field
client.contacts.delete(contact.id)                               # the messages stay

# The threads this person appears in, newest first.
client.contacts.conversations(contact.id).each do |thread|
  puts "#{thread.platform} #{thread.messages} messages, #{thread.received} in"
end

# platform and handle are required columns; any other column is a custom field key.
result = client.contacts.import(workspace_id: workspace_id, csv: "platform,handle\nx,ada_writes")
puts "#{result.created} created, #{result.merged} merged"
puts result.unknown_columns.inspect

# The columns your workspace keeps.
fields = client.contacts.list_fields(workspace_id)
field = client.contacts.create_field(workspace_id: workspace_id, key: 'plan_tier',
                                     name: 'Plan Tier', type: 'select', options: %w[Free Pro])
client.contacts.update_field(field.id, name: 'Tier')
client.contacts.delete_field(field.id)   # removes every answer to it

# Volume and median reply time per thread. Needs the `analytics` scope.
report = client.contacts.conversation_analytics(days: 30, sort: 'slowest')
puts report.conversations.first.median_response_minutes
```

## Broadcasts

One message into every conversation you already have with a segment of your contacts. Nothing is sent into a closed messaging window: Messenger and Instagram take a business-initiated message only within 24 hours of the contact's last one, so recipients outside it come back skipped with `window_closed` rather than attempted. Telegram, Slack, Bluesky and Reddit have no window.

Reading needs the `inbox` scope; `send` and `cancel` also need `publish`.

```ruby
page = client.broadcasts.list(workspace_id: workspace_id, status: 'sent')
page.each { |b| puts "#{b.name} — #{b.counts.sent} sent, #{b.counts.skipped} skipped" }

broadcast = client.broadcasts.create(
  workspace_id: workspace_id,
  account_id: account_id,
  name: 'September check-in',
  text: 'New colours just landed. Want a look?',
  audience: { 'platforms' => ['instagram'] }
)

# The recipients count is how many contacts matched, not how many will be
# messaged — the messaging window decides that.
client.broadcasts.send(broadcast.id)

# Who was skipped, and why.
client.broadcasts.recipients(broadcast.id, status: 'skipped').each do |r|
  puts "#{r.display_name}: #{r.skip_reason}"
end
```

## Sequences

A series of messages, each a delay after the one before, walked per enrolled contact. The messaging window applies to every step: one that comes due outside it is skipped rather than sent, and the enrollment carries on.

```ruby
sequence = client.sequences.create(
  workspace_id: workspace_id,
  account_id: account_id,
  name: 'Welcome',
  steps: [
    { 'delay_hours' => 0, 'text' => 'Thanks for the follow — anything I can help with?' },
    { 'delay_hours' => 48, 'text' => 'Here is what people usually ask us first.' }
  ]
)

# By id, or by the same audience filter a broadcast takes.
client.sequences.enroll(sequence.id, contact_ids: [contact_id])
client.sequences.enroll(sequence.id, audience: { 'platforms' => ['telegram'] })

# Nothing further fires for them.
client.sequences.unenroll(sequence.id, [contact_id])

client.sequences.enrollments(sequence.id).each do |e|
  puts "#{e.display_name} — step #{e.step}, #{e.status}"
end
```
## Knowledge

What the workspace has told FoPost about itself. Retrieval over these sources
is what grounds a drafted inbox reply in your own answers instead of an
invented one. Needs the `inbox` scope.

```ruby
# A source is an FAQ, a note, a page on your own site, or a plain-text/CSV
# media item. Adding one queues it for indexing, so it comes back `pending`.
faq = client.knowledge.create(
  kind: 'faq',
  title: 'Refunds and returns',
  content: "Q: How long do refunds take?\nA: Up to 30 days from the request.",
  workspace_id: workspace.id,
)
page = client.knowledge.create(kind: 'url', title: 'Shipping', url: 'https://yourbrand.com/shipping')

client.knowledge.list(workspace_id: workspace.id).each do |source|
  puts "#{source.title} #{source.status} #{source.chunk_count}"
end

# Editing the text or the URL re-indexes the source on its own; a page you
# changed on your own site needs an explicit re-read.
client.knowledge.update(faq.id, title: 'Refunds')
client.knowledge.sync(page.id)
client.knowledge.delete(page.id)

# Empty is the honest answer when nothing stored answers the question.
client.knowledge.search('how long do refunds take?', top_k: 3).each do |match|
  puts "#{match.source_title}: #{match.text}"
end
```


## Ads

Meta ads, campaigns, creatives, audiences, insights and lead forms. Every call needs the `ads` scope; `boost`, `create`, `set_status`, `delete`, `bulk_set_status` and the create, update, delete and duplicate calls for campaigns, ad sets and network ads spend money and also need `publish`. A boost, campaign, ad set or ad starts paused unless you pass `paused: false`.

```ruby
url = client.ads.authorize_meta(workspace_id: workspace.id)   # finish the Meta login in a browser
source = client.ads.sources(workspace_id: workspace.id).first

ad = client.ads.boost(
  workspace_id: workspace.id,
  connection_id: source.connection_id,
  ad_account_id: source.ad_accounts.first['id'],
  post_id: post.id,
  account_id: accounts.first.id,
  name: 'Launch boost',
  goal: 'engagement',
  budget: { minor: 5000, type: 'daily' },
  targeting: { countries: ['US'] }
)

client.ads.set_status(ad.id, workspace_id: workspace.id, status: 'active')
client.ads.refresh(ad.id, workspace_id: workspace.id).insights.impressions
client.ads.list(workspace_id: workspace.id)
client.ads.external(workspace_id: workspace.id)   # ads made outside FoPost, read live

client.ads.audiences(connection_id: source.connection_id, ad_account_id: 'act_123')
client.ads.search_targeting(connection_id: source.connection_id, type: 'interest', q: 'coffee')
client.ads.lead_forms(workspace_id: workspace.id)
client.ads.leads('form_1', connection_id: source.connection_id, page_id: '42')
```

The campaign tree is read live from Meta by Meta id, so each call names the connection:

```ruby
conn = source.connection_id
tree = client.ads.account_tree('act_123', connection_id: conn, workspace_id: workspace.id)
campaign = client.ads.create_campaign(workspace_id: workspace.id, connection_id: conn, ad_account_id: 'act_123',
                                      name: 'Spring', goal: 'traffic')
ad_set = client.ads.create_ad_set(workspace_id: workspace.id, connection_id: conn, campaign_id: campaign.id,
                                  page_id: '42', name: 'US adults', goal: 'traffic',
                                  budget: { minor: 5000, type: 'daily' },
                                  targeting: { countries: ['US'], ageMin: 18, ageMax: 65, gender: 'all' })
creative = client.ads.create_creative(workspace_id: workspace.id, connection_id: conn, ad_account_id: 'act_123',
                                      page_id: '42', name: 'Hero', format: 'image', text: 'New in store',
                                      media_url: 'https://yourbrand.com/hero.jpg', url_tags: 'utm_source=meta')
client.ads.create_network_ad(workspace_id: workspace.id, connection_id: conn, ad_set_id: ad_set.id,
                             creative_id: creative.id, name: 'Hero ad')
client.ads.bulk_set_status(workspace_id: workspace.id, connection_id: conn, status: 'active',
                           objects: [{ id: campaign.id, level: 'campaign' }])

client.ads.insights(connection_id: conn, object_id: campaign.id, since: '2026-09-01', until: '2026-09-07',
                    breakdown: 'age', daily: true)
client.ads.ad_insights(ad.id, workspace_id: workspace.id, since: '2026-09-01', until: '2026-09-07')

client.ads.subscribe_lead_page(workspace_id: workspace.id, connection_id: conn, page_id: '42')
page = client.ads.leads_feed(workspace_id: workspace.id, limit: 50)
page = client.ads.leads_feed(workspace_id: workspace.id, cursor: page.next_cursor) if page.next_cursor
```

| Group | Methods |
| --- | --- |
| Campaigns | `account_tree`, `create_campaign`, `get_campaign`, `update_campaign`, `delete_campaign`, `duplicate_campaign` |
| Ad sets | `create_ad_set`, `get_ad_set`, `update_ad_set`, `delete_ad_set`, `duplicate_ad_set` |
| Network ads | `create_network_ad`, `get_network_ad`, `update_network_ad`, `delete_network_ad`, `duplicate_network_ad`, `bulk_set_status` |
| Creatives | `creatives`, `create_creative`, `get_creative`, `delete_creative` |
| Audiences | `get_audience`, `update_audience`, `delete_audience`, `add_audience_users`, `estimate_reach` |
| Insights | `insights`, `ad_insights` |
| Leads | `get_lead_form`, `archive_lead_form`, `leads_feed`, `lead_pages`, `subscribe_lead_page`, `unsubscribe_lead_page` |
| Goals | `goals` |
| Catalogs | `catalogs`, `create_catalog`, `catalog`, `update_catalog`, `delete_catalog`, `catalog_products`, `write_catalog_products`, `product_feeds`, `create_product_feed`, `delete_product_feed`, `feed_uploads`, `start_feed_upload`, `product_sets`, `create_product_set`, `update_product_set`, `delete_product_set` |
| Reach and frequency | `reach_frequency`, `create_reach_frequency`, `reach_frequency_prediction`, `reserve_reach_frequency`, `cancel_reach_frequency` |
| Ad Library | `library` |
| Partnership ads | `partnership_creators`, `request_partnership`, `revoke_partnership` |
| Account settings | `account_activity`, `labels`, `create_label`, `update_label`, `delete_label`, `apply_label`, `studies`, `create_study`, `study`, `delete_study`, `ios_campaign_limits`, `high_demand_periods`, `create_high_demand_period`, `delete_high_demand_period`, `value_rule_sets`, `create_value_rule_set`, `delete_value_rule_set` |

## Google Business Profile

Manage a connected Business Profile location: the profile, attributes, food menus, services, photos, action links, verification and performance.

```ruby
location = client.google_business.get_location('acc_1')
client.google_business.update_location('acc_1', title: 'Corner Bakery', website_uri: 'https://yourbrand.com')

# Photos come from your media library, JPEG or PNG.
client.google_business.add_media('acc_1', media_id: media_id, category: 'INTERIOR')

client.google_business.create_place_action('acc_1', uri: 'https://yourbrand.com/book',
                                                    place_action_type: 'APPOINTMENT')

metrics = client.google_business.get_performance('acc_1', start_date: '2026-09-01', end_date: '2026-09-30')
terms = client.google_business.get_search_keywords('acc_1', start_date: '2026-08-01', end_date: '2026-09-01')
```

Responses relay Google's own shape as plain hashes. Reads need the `accounts` scope, writes `publish` as well. Every call raises a 503 `configuration_error` until Google grants the deployment Business Profile API access.

## Media

Direct uploads to the media library, in three steps: presign a slot, PUT the bytes to the returned URL with the returned headers (no API key), then complete. `upload_direct` does all three and returns the media item; a rejected PUT raises before `complete` is called.

```ruby
item = client.media.upload_direct(
  workspace_id: workspace.id,
  filename: 'logo.png',
  mime_type: 'image/png',
  data: File.binread('logo.png')
)
item.id
item.preview_url

# Or step by step
upload = client.media.presign(workspace_id: workspace.id, filename: 'logo.png', mime_type: 'image/png', size: 4096)
upload.upload_url   # PUT the bytes here with upload.headers
client.media.complete(upload.upload_id)
```

## Errors

Every non-2xx response raises. All of them are rescuable as `Fopost::Error`.

| Status  | Class                            |
| ------- | -------------------------------- |
| 400/422 | `Fopost::ValidationError`        |
| 401     | `Fopost::AuthenticationError`    |
| 402     | `Fopost::PaymentRequiredError`   |
| 403     | `Fopost::PermissionDeniedError`  |
| 404     | `Fopost::NotFoundError`          |
| 429     | `Fopost::RateLimitError`         |
| other   | `Fopost::Error`                  |

```ruby
begin
  client.posts.publish(post_id)
rescue Fopost::PaymentRequiredError => e
  warn "Out of credits — upgrade at #{e.upgrade_url}"
rescue Fopost::Error => e
  warn "#{e.status} #{e.code}: #{e.message}"
end
```

`message` is what the API said; `to_s` adds the status and code, so an uncaught error still reports both. `e.body` holds the decoded response, and `Fopost::ValidationError#errors` carries per-field messages when the API sends them.

## Configuration

```ruby
Fopost.new(
  api_key: 'fp_...',                            # or FOPOST_API_KEY
  base_url: 'https://api.fopost.com/v1',    # override for a dev server
  timeout: 30.0,                                # seconds
  max_retries: 3,                               # total attempts on a 429
  transport: MyTransport.new                    # bring your own HTTP stack
)
```

| Env var          | Used for                                    |
| ---------------- | ------------------------------------------- |
| `FOPOST_API_KEY` | API key, when not passed to the constructor |

A `429` is retried automatically, waiting for the interval the API asks for in `Retry-After` (delta-seconds or an HTTP date, capped at 60s). `max_retries` counts total attempts, so the default of 3 means two retries.

## Endpoints the SDK does not wrap yet

`client.request` reaches anything in the API, with the same auth, retries, and error handling:

```ruby
client.request(:get, '/analytics/overview', params: { 'workspace_id' => workspace.id })
client.request(:post, '/webhooks', json: { 'url' => 'https://example.com/hook', 'events' => ['post.published'] })
```

## Swapping the HTTP stack

The default transport is `net/http`. Anything that responds to `call(method:, url:, headers:, body:)` and returns a `Fopost::HTTP::Response` can replace it — useful for a shared connection pool, custom instrumentation, or stubbing the network in tests.

```ruby
class LoggingTransport
  include Fopost::HTTP::Transport

  def initialize(inner) = @inner = inner

  def call(method:, url:, headers:, body:)
    warn "#{method} #{url}"
    @inner.call(method: method, url: url, headers: headers, body: body)
  end
end

client = Fopost.new(transport: LoggingTransport.new(Fopost::HTTP::NetHTTPTransport.new))
```

## Models

Responses come back as small model objects with snake_case readers. The API is not consistent about its wire casing — posts come back snake_case, accounts camelCase — so both spellings parse. Fields the SDK does not model yet stay reachable:

```ruby
post.raw['someNewField']  # the decoded body, exactly as sent
post['some_new_field']    # by either spelling
```

That means a field added server-side never breaks an older client.

## Development

```bash
bundle install
bundle exec rake test
bundle exec rubocop
```

Tests run against a stubbed transport, so nothing touches the network.

## License

MIT. See [LICENSE](LICENSE).

### Google Ads

Campaigns, ad groups, ads, audiences and insights are on `client.ads` and dispatch by
connection. What only Google has is under `client.ads.google`:

```ruby
keywords = client.ads.google.keywords(
  connection_id: 'c4d5e6f7-…',
  customer_id: '1234567890'
)

client.ads.google.create_keyword(
  workspace_id: '7d2b8c11-…',
  connection_id: 'c4d5e6f7-…',
  customer_id: '1234567890',
  ad_group_id: '1234567890~adGroup~77',
  text: 'running shoes',
  match_type: 'EXACT'
)
```

Also `keyword_ideas`, `keyword_metrics`, `search_terms`, `bid_strategies`, `ad_schedule`
and `set_ad_schedule`, the negative keyword lists, `assets` and `asset_groups`,
`local_services_leads`, the conversion methods, and `query` for a raw read-only GAQL
SELECT. Changes need the `publish` scope as well as `ads`; `customer_id` has to name an
account the connection's grant reaches.
