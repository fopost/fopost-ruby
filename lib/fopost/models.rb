# frozen_string_literal: true

require 'fopost/model'

module Fopost
  class MediaItem < Model
    attribute :type
    attribute :name
    attribute :url
    attribute :size
    attribute :alt
    attribute :thumbnail
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
end
