# frozen_string_literal: true

require 'fopost/model'

module Fopost
  class MediaItem < Model
    attribute :id
    attribute :type
    attribute :name
    attribute :url
    attribute :size
    attribute :alt
    attribute :thumbnail
    attribute :preview_url
  end

  # Where and how to PUT the bytes of a direct upload.
  class PresignedUpload < Model
    attribute :upload_id
    attribute :upload_url
    attribute :method
    attribute :headers, :hash
    attribute :expires_at, :time
  end

  # One block of a post. A thread is several blocks in order.
  class ContentBlock < Model
    attribute :id
    attribute :text
    attribute :media, [MediaItem]
    attribute :position
  end

  # A connected social account. Named so it does not read as a user account.
  class SocialAccount < Model
    attribute :id
    attribute :workspace_id
    attribute :platform
    attribute :username
    attribute :name
    attribute :avatar
    attribute :active
    attribute :is_primary
    attribute :health_status
    attribute :last_health_check, :time
    attribute :platform_name
  end

  # The result of renaming an account; `name` is the override when set, else the platform name.
  class AccountRename < Model
    attribute :id
    attribute :name
    attribute :platform_name
  end

  # The result of moving an account to another workspace.
  class AccountMove < Model
    attribute :id
    attribute :workspace_id
  end

  # A one-time code that connects a Telegram chat; send `command` to the bot there.
  class TelegramConnectCode < Model
    attribute :code
    attribute :command
    attribute :bot_username
    attribute :deep_link
    attribute :group_link
    attribute :expires_at, :time
  end

  # Where a connect code stands: `pending`, `connected`, `failed` or `expired`.
  class TelegramConnectStatus < Model
    attribute :status
    attribute :account_id
    attribute :reason
  end

  # One entry in the bot's command menu.
  class TelegramBotCommand < Model
    attribute :command
    attribute :description
  end

  # The command menu the bot shows in a connected chat.
  class TelegramBotCommands < Model
    attribute :commands, [TelegramBotCommand]
  end

  # A tappable prompt Messenger or Instagram shows before the first message.
  class MetaIceBreaker < Model
    attribute :question
    attribute :payload
  end

  # The ice breakers set on one account.
  class MetaIceBreakers < Model
    attribute :ice_breakers, [MetaIceBreaker]
  end

  # A menu item: a `postback` with a payload, or a `web_url` with a link.
  class MetaMenuItem < Model
    attribute :type
    attribute :title
    attribute :payload
    attribute :url
  end

  # One locale's menu; `default` is the fallback every language uses.
  class MetaPersistentMenuEntry < Model
    attribute :locale
    attribute :call_to_actions, [MetaMenuItem]
    attribute :composer_input_disabled
  end

  # The persistent menu set on one account, one entry per locale.
  class MetaPersistentMenu < Model
    attribute :persistent_menu, [MetaPersistentMenuEntry]
  end

  # One locale's greeting, up to 160 characters.
  class MetaGreetingText < Model
    attribute :locale
    attribute :text
  end

  # The greeting set on one account, one entry per locale.
  class MetaGreeting < Model
    attribute :greeting, [MetaGreetingText]
  end

  # What the network delivers to the FoPost webhook for one account.
  class WebhookSubscription < Model
    attribute :subscribed
    attribute :fields
    attribute :missing_fields
  end

  # The outcome of a Messenger thread hand-over; `app_id` is nil when control was taken back.
  class InboxHandover < Model
    attribute :app_id
    attribute :control
  end

  # A channel the Slack app can post to; `is_current` marks the one this account posts to.
  class SlackChannel < Model
    attribute :id
    attribute :name
    attribute :is_private
    attribute :is_member
    attribute :is_current
  end

  # A person in the connected Slack workspace; `id` is the handle for starting a DM.
  class SlackMember < Model
    attribute :id
    attribute :name
    attribute :real_name
    attribute :display_name
    attribute :avatar
    attribute :is_bot
  end

  # The name and icon a Slack account posts under; nil means the app default.
  class SlackIdentity < Model
    attribute :username
    attribute :icon_url
    attribute :icon_emoji
  end

  # A Discord text channel the bot can post to; `is_current` marks this account's.
  class DiscordChannel < Model
    attribute :id
    attribute :name
    # Discord's channel type: 0 text, 5 announcement, 15 forum.
    attribute :type
    attribute :parent_id
    attribute :nsfw
    # False when a channel permission in Discord shuts the bot out.
    attribute :can_post
    attribute :is_current
  end

  # The nickname and avatar the bot wears in the server; nil means its own.
  class DiscordIdentity < Model
    attribute :username
    attribute :avatar_url
  end

  # A message in the connected channel.
  class DiscordMessage < Model
    attribute :id
    attribute :channel_id
    attribute :content
    attribute :author_id
    attribute :author_name
    attribute :pinned
    attribute :created_at
  end

  # A message the bot put somewhere.
  class DiscordMessageRef < Model
    attribute :id
    attribute :channel_id
  end

  # A thread started on a message.
  class DiscordThread < Model
    attribute :id
    attribute :name
    attribute :parent_id
  end

  # An event on the server's calendar; `channel_id` is a voice or stage channel,
  # otherwise `location` says where it happens.
  class DiscordScheduledEvent < Model
    attribute :id
    attribute :name
    attribute :description
    attribute :channel_id
    attribute :location
    attribute :start_time
    attribute :end_time
    # One of scheduled, active, completed, canceled.
    attribute :status
    attribute :user_count
  end

  # A person in the connected server; `id` is the member id for a DM or a role.
  class DiscordMember < Model
    attribute :id
    attribute :username
    attribute :display_name
    attribute :nick
    attribute :avatar
    attribute :is_bot
    attribute :roles
    attribute :joined_at
  end

  # A role in the connected server; `permissions` is Discord's bitfield as a decimal string.
  class DiscordRole < Model
    attribute :id
    attribute :name
    attribute :color
    attribute :hoist
    attribute :mentionable
    # A managed role belongs to an integration and cannot be edited.
    attribute :managed
    attribute :position
    attribute :permissions
  end

  # A named set of connected accounts in one workspace.
  class AccountGroup < Model
    attribute :id
    attribute :name
    attribute :account_ids
    attribute :created_at, :time
    attribute :updated_at, :time
  end

  # An account a post is targeted at, plus its per-account delivery state.
  class PostAccount < Model
    attribute :id
    attribute :platform
    attribute :username
    attribute :name
    attribute :avatar
    attribute :publish_status
    attribute :posted_at, :time
    attribute :platform_post_id
    attribute :external_url
    attribute :error_code
    attribute :error_message
    attribute :attempts
    attribute :max_attempts
  end

  class Label < Model
    attribute :id
    attribute :name
    attribute :color
    attribute :workspace, :hash
  end

  class Post < Model
    attribute :id
    attribute :workspace_id
    attribute :status
    attribute :content_type
    attribute :schedule_at, :time
    attribute :title
    attribute :summary
    attribute :repeatable
    attribute :repeatable_times
    attribute :repeatable_gap
    attribute :repeatable_gap_unit
    attribute :remaining_posts
    attribute :auto_plug
    attribute :auto_plug_content
    attribute :approved_at, :time
    attribute :rejection_reason
    attribute :content, [ContentBlock]
    attribute :accounts, [PostAccount]
    attribute :labels, [Label]
    attribute :settings, :hash
    attribute :created_at, :time
    attribute :updated_at, :time
  end

  class Workspace < Model
    attribute :id
    attribute :name
    attribute :slug
    attribute :type
    attribute :logo
    attribute :website
    attribute :timezone
    attribute :country
    attribute :description
    attribute :language
    attribute :require_approval
    attribute :ai_alt_text_enabled
    attribute :brand_color
    attribute :role
    attribute :created_at, :time
    attribute :accounts, [SocialAccount]
  end

  # One post-to-account delivery attempt.
  class Delivery < Model
    attribute :id
    attribute :account_id
    attribute :status
    attribute :platform
    attribute :username
    attribute :account_name
    attribute :error_code
    attribute :error_message
    attribute :attempts
    attribute :max_attempts
    attribute :scheduled_publish_at, :time
    attribute :delay_reason
    attribute :delay_message
    attribute :posted_at, :time
    attribute :last_attempt_at, :time
    attribute :platform_post_id
    attribute :external_url
  end

  class PageMeta < Model
    attribute :current_page
    attribute :per_page
    attribute :total
    attribute :last_page
    attribute :from
    attribute :to
  end

  # One page of a list endpoint: its items plus the pagination meta.
  class Page
    include Enumerable

    attr_reader :items, :meta

    def initialize(items: [], meta: PageMeta.new)
      @items = items
      @meta = meta
    end

    def each(&block)
      return items.each unless block

      items.each(&block)
      self
    end

    def [](index)
      items[index]
    end

    def size
      items.size
    end
    alias length size
    alias count size

    def empty?
      items.empty?
    end

    def inspect
      "#<Fopost::Page items=#{items.size} total=#{meta.total.inspect}>"
    end
  end

  # Credits charged by one AI call, and what is left afterwards.
  class AiCredits < Model
    attribute :charged
    attribute :remaining
  end

  class AiCreditBalance < Model
    attribute :credits_remaining
    attribute :credits_used
    attribute :credits_total
    attribute :period_start, :time
    attribute :period_end, :time
  end

  class CaptionResult < Model
    attribute :caption
    attribute :credits, AiCredits
  end

  class RewriteVariant < Model
    attribute :platform
    attribute :content
    attribute :credits
  end

  class RewriteResult < Model
    attribute :results, [RewriteVariant]
    attribute :credits, AiCredits
  end

  class RepurposeResult < Model
    attribute :url
    attribute :title
    attribute :posts, :hash
    attribute :credits, AiCredits
  end

  # Advisory note from a validate call; never blocks publishing.
  class ValidateSignal < Model
    attribute :level
    attribute :code
    attribute :message
  end

  class ValidatePostPlatform < Model
    attribute :platform
    attribute :ready
    attribute :issues
    attribute :score
    attribute :signals, [ValidateSignal]
  end

  class ValidatePostResult < Model
    attribute :ready
    attribute :platforms, [ValidatePostPlatform]
  end

  class ValidateLengthPlatform < Model
    attribute :platform
    attribute :length
    attribute :limit
    attribute :unit
    attribute :ok
    attribute :signals, [ValidateSignal]
  end

  class ValidateLengthResult < Model
    attribute :ok
    attribute :platforms, [ValidateLengthPlatform]
  end

  class ValidateMediaResult < Model
    attribute :ok
    attribute :issues
    attribute :name
    attribute :size
    attribute :mime_type
    attribute :type
  end

  # `page`, `per_page`, `total` on the inbox list endpoints.
  class InboxPageMeta < Model
    attribute :page
    attribute :per_page
    attribute :total
  end

  class InboxAccountRef < Model
    attribute :id
    attribute :platform
    attribute :username
    attribute :name
    attribute :avatar
  end

  class InboxAttachment < Model
    attribute :kind
    attribute :name
    attribute :width
    attribute :height
    attribute :link
    attribute :url
    attribute :preview_url
  end

  # The platform post an item sits under, whoever published it.
  class InboxPostContext < Model
    attribute :external_id
    attribute :is_own
    attribute :text
    attribute :author_name
    attribute :author_handle
    attribute :author_avatar_url
    attribute :thumbnail_url
    attribute :permalink
    attribute :published_at, :time
    attribute :published, :hash
  end

  # A comment, mention, review or direct message on a connected account.
  class InboxItem < Model
    attribute :id
    attribute :workspace_id
    attribute :platform
    attribute :type
    attribute :state
    attribute :direction
    attribute :conversation_id
    attribute :author_name
    attribute :author_handle
    attribute :author_avatar_url
    attribute :text
    # Stars on a review, 1-5. Nil on every other type.
    attribute :rating
    attribute :attachments, [InboxAttachment]
    attribute :permalink
    attribute :post_external_id
    attribute :parent_external_id
    attribute :platform_created_at, :time
    attribute :snoozed_until, :time
    attribute :replied_at, :time
    attribute :created_at, :time
    attribute :can_reply
    attribute :hidden
    attribute :liked
    attribute :pinned
    attribute :reaction
    attribute :edited_at, :time
    attribute :can_hide
    attribute :can_delete
    attribute :can_like
    attribute :can_pin
    attribute :can_edit
    attribute :can_react
    attribute :can_send_media
    attribute :can_quick_reply
    attribute :can_private_reply
    # The platform's own state: published, held, spam or rejected.
    attribute :moderation_status
    attribute :post, :hash
    attribute :post_context, InboxPostContext
    attribute :account, InboxAccountRef
  end

  # One platform post and the comments it has collected.
  class InboxThread < Model
    attribute :workspace_id
    attribute :account_id
    attribute :post_external_id
    attribute :comment_count
    attribute :unread_count
    attribute :last_comment_at, :time
    attribute :last_comment_text
    attribute :last_comment_author
    # Stars, on a review thread. Nil on comments and mentions.
    attribute :rating
    attribute :post, InboxPostContext
    attribute :account, InboxAccountRef
  end

  # One direct-message thread.
  class InboxConversation < Model
    attribute :workspace_id
    attribute :account_id
    attribute :conversation_id
    attribute :message_count
    attribute :unread_count
    attribute :last_message_at, :time
    attribute :last_message_text
    attribute :last_message_outbound
    attribute :participant, :hash
    attribute :account, InboxAccountRef
  end

  class InboxAccount < Model
    attribute :id
    attribute :workspace_id
    attribute :platform
    attribute :username
    attribute :name
    attribute :avatar
    attribute :inbox_supported
    attribute :pending_reason
    attribute :dm_supported
    attribute :dm_pending_reason
    attribute :can_start_conversation
    # The grant predates a permission the inbox needs; reconnect the account once.
    attribute :reconnect_required
  end

  # One thing the workspace has told FoPost about itself: an FAQ, a note, a page
  # on its own site, or a plain-text/CSV file from the media library.
  class KnowledgeSource < Model
    attribute :id
    # `faq`, `text`, `url` or `file`.
    attribute :kind
    attribute :title
    # Only a `ready` source is searched.
    attribute :status
    # Why the last sync failed, in plain words.
    attribute :status_message
    # Set for `url` sources.
    attribute :url
    # Set for `file` sources: the media library item read.
    attribute :media_id
    # nil means the source serves the whole workspace.
    attribute :brand_voice_id
    # Searchable passages the last sync produced.
    attribute :chunk_count
    # The typed text, for `faq` and `text` sources only.
    attribute :content
    attribute :last_synced_at, :time
    attribute :created_at, :time
    attribute :updated_at, :time
  end

  # One retrieved passage, with the source it came from so a reply can cite it.
  class KnowledgeMatch < Model
    attribute :source_id
    attribute :source_title
    attribute :source_kind
    attribute :source_url
    attribute :text
    # Similarity to the question, 0-1.
    attribute :score
  end

  class InboxPlatform < Model
    attribute :platform
    attribute :comments
    attribute :dms
  end

  # A drafted reply a person still has to send.
  class InboxApproval < Model
    attribute :id
    attribute :workspace_id
    attribute :source
    attribute :reply
    attribute :created_at, :time
    attribute :item, :hash
  end

  class InboxReplyResult < Model
    attribute :item, InboxItem
    attribute :reply, :hash
  end

  # A DM opened by handle or as a private reply to a comment.
  class InboxStartedConversation < Model
    attribute :conversation_id
    attribute :item, InboxItem
  end

  class InboxRefreshResult < Model
    attribute :accounts_polled
    attribute :new_items
    attribute :rate_limited
    attribute :dm_reconnect
  end

  # Lifetime numbers from the last refresh. `spend_minor` is in the ad
  # account currency, minor units.
  class AdInsights < Model
    attribute :impressions
    attribute :reach
    attribute :clicks
    attribute :spend_minor
  end

  # A boost or standalone ad created through FoPost.
  class Ad < Model
    attribute :id
    attribute :workspace_id
    attribute :kind
    attribute :name
    attribute :goal
    attribute :status
    attribute :effective_status
    attribute :connection_id
    attribute :account_id
    attribute :platform
    attribute :ad_account_id
    attribute :source_post_id
    attribute :budget_minor
    attribute :budget_type
    attribute :currency
    attribute :end_at, :time
    attribute :targeting, :hash
    attribute :creative, :hash
    attribute :insights, AdInsights
    attribute :insights_at, :time
    attribute :last_error
    attribute :created_at, :time
  end

  # An ad on a connected ad account that was made outside FoPost.
  class ExternalAd < Model
    attribute :id
    attribute :name
    attribute :effective_status
    attribute :campaign_id
    attribute :campaign_name
    attribute :objective
    attribute :budget_minor
    attribute :budget_type
    attribute :end_at, :time
    attribute :created_at, :time
    attribute :connection_id
    attribute :ad_account_id
    attribute :currency
    attribute :workspace_id
  end

  class AdConnection < Model
    attribute :id
    attribute :provider
    attribute :auth_type
    attribute :name
    attribute :business_id
    attribute :created_at, :time
    attribute :workspace_id
  end

  # A connection with the ad accounts and Pages its grant reaches.
  class AdSource < Model
    attribute :connection_id
    attribute :name
    attribute :workspace_id
    attribute :ad_accounts
    attribute :pages
    attribute :error
  end

  class BoostablePost < Model
    attribute :id
    attribute :workspace_id
    attribute :text
    attribute :thumbnail_url
    attribute :deliveries
  end

  class Audience < Model
    attribute :id
    attribute :name
    attribute :subtype
    attribute :description
    attribute :size_lower
    attribute :size_upper
    attribute :delivery_status
    attribute :created_at
  end

  class AudiencesResult < Model
    attribute :audiences, [Audience]
    attribute :pixels
    attribute :workspace_id
  end

  class TargetingOption < Model
    attribute :id
    attribute :name
    attribute :detail
  end

  class LeadForm < Model
    attribute :id
    attribute :name
    attribute :status
    attribute :leads_count
    attribute :created_at
    attribute :questions
  end

  class LeadFormSource < Model
    attribute :connection_id
    attribute :connection_name
    attribute :page_id
    attribute :page_name
    attribute :forms, [LeadForm]
    attribute :error
    attribute :workspace_id
  end

  class Lead < Model
    attribute :id
    attribute :created_at
    attribute :fields
    attribute :ad_name
    attribute :campaign_name
    attribute :platform
    attribute :is_organic
  end

  # One page of leads; pass `next_cursor` back as `after:` for the next.
  class LeadsPage < Model
    attribute :leads, [Lead]
    attribute :next_cursor
  end

  # A Meta ad inside an ad set. Read live from Meta, never stored.
  class NetworkAd < Model
    attribute :id
    attribute :name
    attribute :campaign_id
    attribute :ad_set_id
    attribute :creative_id
    attribute :status
    attribute :effective_status
    attribute :created_at, :time
  end

  class AdSet < Model
    attribute :id
    attribute :name
    attribute :campaign_id
    attribute :status
    attribute :effective_status
    attribute :budget_minor
    attribute :budget_type
    attribute :end_at, :time
    attribute :optimization_goal
    attribute :created_at, :time
    attribute :ads, [NetworkAd]
  end

  class AdCampaign < Model
    attribute :id
    attribute :name
    attribute :status
    attribute :effective_status
    attribute :objective
    attribute :budget_minor
    attribute :budget_type
    attribute :created_at, :time
    attribute :ad_sets, [AdSet]
  end

  # Campaigns with their ad sets and ads, read live from Meta.
  class AdAccountTree < Model
    attribute :ad_account_id
    attribute :currency
    attribute :workspace_id
    attribute :campaigns, [AdCampaign]
  end

  class BulkAdStatusResult < Model
    attribute :id
    attribute :level
    attribute :ok
    attribute :error
  end

  class AdCreative < Model
    attribute :id
    attribute :name
    attribute :format
    attribute :status
    attribute :title
    attribute :body
    attribute :link
    attribute :thumbnail_url
    attribute :call_to_action
    attribute :url_tags
  end

  # ─── Product catalogs ──────────────────────────────────────────

  # A product catalog on the connection's business portfolio, read live.
  class ProductCatalog < Model
    attribute :id
    attribute :name
    attribute :vertical
    attribute :product_count
  end

  class ProductCatalogsResult < Model
    attribute :catalogs, [ProductCatalog]
    attribute :workspace_id
  end

  # One product in a catalog. `price_minor` is minor units of `currency`.
  class CatalogProduct < Model
    attribute :id
    # Your own key for the product.
    attribute :retailer_id
    attribute :name
    attribute :description
    attribute :availability
    attribute :condition
    attribute :price_minor
    attribute :currency
    attribute :image_url
    attribute :url
  end

  class CatalogProductsPage < Model
    attribute :products, [CatalogProduct]
    attribute :next_cursor
  end

  class CatalogBatchResult < Model
    attribute :handles
    # Products sent in this batch.
    attribute :accepted
  end

  # Keeps a catalog in step with a product file you host.
  class ProductFeed < Model
    attribute :id
    attribute :name
    attribute :url
    attribute :schedule
    attribute :created_at, :time
  end

  class ProductFeedUpload < Model
    attribute :id
    attribute :started_at, :time
    attribute :ended_at, :time
    attribute :status
    attribute :error_count
    attribute :warning_count
  end

  # The slice of a catalog one catalog ad runs from.
  class ProductSet < Model
    attribute :id
    attribute :name
    attribute :product_count
    # The network's own product-set filter.
    attribute :filter
  end

  # ─── Reach and frequency ───────────────────────────────────────

  # A priced flight. Nothing is bought until it is reserved.
  class ReachFrequencyPrediction < Model
    attribute :id
    attribute :name
    attribute :status
    attribute :reach
    attribute :impressions
    attribute :frequency_cap
    # Account currency, minor units.
    attribute :budget_minor
    attribute :start_at, :time
    attribute :end_at, :time
    # True once the prediction holds inventory.
    attribute :reserved
  end

  class ReachFrequencyResult < Model
    attribute :predictions, [ReachFrequencyPrediction]
    attribute :workspace_id
  end

  # ─── Ad Library ────────────────────────────────────────────────

  # One public archive entry. Read live on every search and stored nowhere.
  class AdLibraryEntry < Model
    attribute :id
    attribute :page_id
    attribute :page_name
    attribute :bodies
    attribute :titles
    attribute :link_urls
    attribute :snapshot_url
    attribute :publisher_platforms
    attribute :started_at, :time
    attribute :ended_at, :time
    # Only on the archive's disclosure entries.
    attribute :currency
    attribute :spend_lower
    attribute :spend_upper
    attribute :impressions_lower
    attribute :impressions_upper
  end

  class AdLibraryPage < Model
    attribute :entries, [AdLibraryEntry]
    attribute :next_cursor
  end

  # ─── Partnership ads ───────────────────────────────────────────

  # A creator who allowlisted this advertiser for partnership ads.
  class PartnershipCreator < Model
    attribute :id
    attribute :username
    attribute :name
    attribute :status
    attribute :permissions
  end

  # ─── Ad account settings ───────────────────────────────────────

  class AdActivity < Model
    attribute :id
    attribute :event_type
    attribute :actor_name
    attribute :object_name
    attribute :object_type
    attribute :extra_data
    attribute :created_at, :time
  end

  class AdActivityResult < Model
    attribute :activity, [AdActivity]
    attribute :workspace_id
  end

  # Groups campaigns, ad sets and ads for reporting.
  class AdLabel < Model
    attribute :id
    attribute :name
    attribute :created_at, :time
  end

  # An A/B study splitting traffic across its cells.
  class AdStudy < Model
    attribute :id
    attribute :name
    attribute :description
    attribute :type
    attribute :status
    attribute :start_at, :time
    attribute :end_at, :time
  end

  # How many iOS 14 campaigns an ad account may run at once, per app.
  class IosCampaignLimits < Model
    attribute :limit
    attribute :used
    attribute :app_id
  end

  # A window the network should expect heavier spend over.
  class HighDemandPeriod < Model
    attribute :id
    attribute :start_at, :time
    attribute :end_at, :time
    attribute :budget_value
    attribute :budget_value_type
  end

  # Weights conversions so some audiences count for more than others.
  class ValueRuleSet < Model
    attribute :id
    attribute :name
    attribute :status
    attribute :rules
  end

  class ReachEstimate < Model
    attribute :lower
    attribute :upper
    attribute :ready
  end

  # `spend_minor` is in the ad account currency, minor units; `ctr` is a percentage.
  class InsightsMetrics < Model
    attribute :impressions
    attribute :reach
    attribute :clicks
    attribute :spend_minor
    attribute :ctr
    attribute :leads
  end

  class InsightsBreakdownRow < Model
    attribute :key
    attribute :metrics, InsightsMetrics
  end

  class InsightsTimelineRow < Model
    attribute :date
    attribute :metrics, InsightsMetrics
  end

  class AdInsightsReport < Model
    attribute :currency
    attribute :since
    attribute :until
    attribute :breakdown_by
    attribute :totals, InsightsMetrics
    attribute :breakdown, [InsightsBreakdownRow]
    attribute :timeline, [InsightsTimelineRow]

    # The Meta id the report covers; `object_id` is taken by Ruby itself.
    def meta_object_id
      self['objectId']
    end
  end

  class LeadFormDetail < Model
    attribute :id
    attribute :name
    attribute :status
    attribute :leads_count
    attribute :created_at, :time
    attribute :questions
    attribute :page_id
    attribute :privacy_policy_url
    attribute :locale
  end

  # A lead stored from a subscribed Page.
  class FeedLead < Model
    attribute :id
    attribute :lead_id
    attribute :connection_id
    attribute :page_id
    attribute :form_id
    attribute :ad_id
    attribute :ad_name
    attribute :campaign_name
    attribute :platform
    attribute :is_organic
    attribute :fields
    attribute :submitted_at, :time
    attribute :workspace_id
  end

  # One page of the leads feed; pass `next_cursor` back as `cursor:` for the next.
  class LeadsFeedPage < Model
    attribute :leads, [FeedLead]
    attribute :next_cursor
  end

  # Who did something: `user`, `api_key`, `agent` or `system`.
  class ActivityActor < Model
    attribute :type
    attribute :name
  end

  # One thing that happened in a workspace. A `security` kind is an audit row.
  class ActivityEvent < Model
    attribute :id
    attribute :workspace_id
    attribute :kind
    attribute :ref_type
    attribute :ref_id
    attribute :summary
    attribute :actor, ActivityActor
    attribute :time, :time
  end

  # One page of activity; pass `next_cursor` back as `cursor:` for the next.
  class ActivityPage < Model
    attribute :events, [ActivityEvent]
    attribute :next_cursor
  end

  class LeadPage < Model
    attribute :connection_id
    attribute :page_id
    attribute :page_name
    attribute :created_at, :time
    attribute :workspace_id
  end
  # ─── Contacts ────────────────────────────────────────────────────

  # One handle on one network. The handle is lower-cased with no leading @.
  class ContactChannel < Model
    attribute :platform
    attribute :handle
    # The platform's own id for this person, when the network gave us one.
    attribute :external_id
  end

  class ContactLabel < Model
    attribute :id
    attribute :name
    attribute :color
  end

  # One person, however many handles they write from.
  class Contact < Model
    attribute :id
    attribute :display_name
    attribute :channels, [ContactChannel]
    # inbox, radar or import — what first created the row.
    attribute :source
    attribute :note
    attribute :first_seen_at, :time
    attribute :last_seen_at, :time
    # Custom field values, keyed by field key.
    attribute :fields, :hash
    attribute :labels, [ContactLabel]
    # Only on a listing that spans workspaces.
    attribute :workspace_id
  end

  # One thread a contact appears in.
  class ContactConversation < Model
    # How the inbox groups it: DM thread id, else root post id, else handle.
    attribute :key
    attribute :account_id
    attribute :account_username
    attribute :platform
    attribute :messages
    attribute :received
    attribute :sent
    attribute :last_message_at, :time
    attribute :last_item_id
  end

  class ContactImportSkip < Model
    attribute :row
    attribute :reason
  end

  # What a CSV import did.
  class ContactImportResult < Model
    attribute :created
    # Rows that folded into a contact already on file.
    attribute :merged
    attribute :skipped, [ContactImportSkip]
    # Columns that named neither a reserved field nor a custom field.
    attribute :unknown_columns
  end

  # A column the workspace invented to keep about its contacts.
  class ContactField < Model
    attribute :id
    # Lower-case key, also the CSV column header. Fixed once created.
    attribute :key
    attribute :name
    # text, number, date, select or boolean.
    attribute :type
    # Allowed values when the type is select.
    attribute :options
    attribute :position
  end

  class ConversationAnalyticsRow < Model
    attribute :key
    attribute :account_id
    attribute :platform
    attribute :received
    attribute :sent
    attribute :answered
    attribute :open
    # Median minutes to the first reply in this thread.
    attribute :median_response_minutes
    attribute :first_message_at, :time
    attribute :last_message_at, :time
  end

  # Inbox analytics broken out per thread.
  class ConversationAnalytics < Model
    attribute :conversations, [ConversationAnalyticsRow]
    attribute :total
    attribute :page
    attribute :per_page
  end

  # The pagination block a contacts listing returns.
  class ContactPageMeta < Model
    attribute :page
    attribute :per_page
    attribute :total
  end

  # ─── Broadcasts and sequences ────────────────────────────────────

  # What became of a broadcast's recipients, by status.
  class BroadcastCounts < Model
    attribute :total
    attribute :sent
    # Usually the messaging window doing its job.
    attribute :skipped
    attribute :failed
    attribute :pending
  end

  # One message, sent into conversations the workspace already has.
  class Broadcast < Model
    attribute :id
    # Internal only; never sent to anyone.
    attribute :name
    attribute :text
    attribute :account_id
    attribute :audience, :hash
    # draft, scheduled, sending, sent or cancelled.
    attribute :status
    attribute :scheduled_at, :time
    attribute :sent_at, :time
    attribute :created_at, :time
    attribute :counts, BroadcastCounts
    # Only on a listing that spans workspaces.
    attribute :workspace_id
  end

  # One contact on one broadcast, and what became of their message.
  class BroadcastRecipient < Model
    attribute :contact_id
    attribute :display_name
    # pending, sent, skipped or failed.
    attribute :status
    # Why nothing was sent: window_closed, no_conversation or
    # unsupported_platform. window_closed means the network's messaging
    # window had shut, so nothing was attempted.
    attribute :skip_reason
    attribute :sent_at, :time
    attribute :error
  end

  # One message and how long after the previous step it goes out.
  class SequenceStep < Model
    attribute :delay_hours
    attribute :text
    attribute :media_id
  end

  # Where a sequence's enrollments stand, by status.
  class SequenceEnrollmentCounts < Model
    attribute :total
    attribute :active
    attribute :completed
    attribute :stopped
    attribute :failed
  end

  # A series of messages, each a delay after the one before.
  class Sequence < Model
    attribute :id
    attribute :name
    attribute :account_id
    attribute :steps, [SequenceStep]
    # active or paused. A paused sequence fires nothing.
    attribute :status
    attribute :created_at, :time
    attribute :enrollments, SequenceEnrollmentCounts
    # Only on a listing that spans workspaces.
    attribute :workspace_id
  end

  # One contact walking one sequence.
  class Enrollment < Model
    attribute :id
    attribute :contact_id
    attribute :display_name
    # Steps already sent, so also the index of the next one.
    attribute :step
    attribute :next_at, :time
    # active, completed, stopped or failed.
    attribute :status
    attribute :last_sent_at, :time
    # On a skipped step, the reason it was skipped.
    attribute :error
  end
end
