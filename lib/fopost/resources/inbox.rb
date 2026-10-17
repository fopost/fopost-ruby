# frozen_string_literal: true

module Fopost
  module Resources
    # `client.inbox` — comments, mentions, reviews and direct messages on connected
    # accounts. Every method needs the `inbox` scope.
    class Inbox < Base
      # One page of items, newest first. The result is Enumerable over its items.
      #
      # `type` is comment, mention, review or dm; `state` is unread, read, resolved or
      # snoozed; `sort` is newest, oldest or unanswered.
      def list(workspace_id: nil, type: nil, state: nil, platform: nil, account_id: nil, post_id: nil,
               post_external_id: nil, conversation_id: nil, direction: nil, q: nil, sort: nil,
               page: 1, per_page: 25)
        body = http.get(
          '/inbox',
          {
            'workspace_id' => workspace_id,
            'type' => type,
            'state' => state,
            'platform' => platform,
            'account_id' => account_id,
            'post_id' => post_id,
            'post_external_id' => post_external_id,
            'conversation_id' => conversation_id,
            'direction' => direction,
            'q' => q,
            'sort' => sort,
            'page' => page,
            'per_page' => per_page
          }
        )
        page_of(InboxItem, body)
      end

      # One row per post with comments; `kind: 'mentions'` for posts the
      # account was tagged in, `kind: 'reviews'` for one row per review left
      # on the business, each carrying its rating.
      def threads(workspace_id: nil, kind: nil, platform: nil, account_id: nil, state: nil, q: nil,
                  sort: nil, page: 1, per_page: 25)
        body = http.get(
          '/inbox/posts',
          {
            'workspace_id' => workspace_id,
            'kind' => kind,
            'platform' => platform,
            'account_id' => account_id,
            'state' => state,
            'q' => q,
            'sort' => sort,
            'page' => page,
            'per_page' => per_page
          }
        )
        page_of(InboxThread, body)
      end

      # One row per DM thread, latest first.
      def conversations(workspace_id: nil, platform: nil, account_id: nil, state: nil, q: nil, sort: nil,
                        page: 1, per_page: 25)
        body = http.get(
          '/inbox/conversations',
          {
            'workspace_id' => workspace_id,
            'platform' => platform,
            'account_id' => account_id,
            'state' => state,
            'q' => q,
            'sort' => sort,
            'page' => page,
            'per_page' => per_page
          }
        )
        page_of(InboxConversation, body)
      end

      def unread_count(workspace_id: nil)
        body = http.get('/inbox/unread-count', { 'workspace_id' => workspace_id })
        count = body.is_a?(Hash) ? body['count'] : nil
        count.is_a?(Integer) ? count : 0
      end

      # Every active account, flagged with whether comments and DMs can be read for it.
      def accounts(workspace_id: nil)
        parse_list(InboxAccount, unwrap(http.get('/inbox/accounts', { 'workspace_id' => workspace_id })))
      end

      def platforms
        parse_list(InboxPlatform, unwrap(http.get('/inbox/platforms')))
      end

      # Mark a whole comment thread or DM thread read. Returns how many items changed.
      def mark_thread_read(workspace_id:, account_id:, post_external_id: nil, conversation_id: nil)
        body = compact_nil(
          'workspace_id' => workspace_id,
          'account_id' => account_id,
          'post_external_id' => post_external_id,
          'conversation_id' => conversation_id
        )
        result = unwrap(http.post('/inbox/read', body))
        updated = result.is_a?(Hash) ? result['updated'] : nil
        updated.is_a?(Integer) ? updated : 0
      end

      # Poll every inbox-capable account in the workspace now.
      def refresh(workspace_id:)
        InboxRefreshResult.new(unwrap(http.post('/inbox/refresh', { 'workspace_id' => workspace_id })))
      end

      # Set the item's state to unread, read, resolved or snoozed. A snooze
      # needs `snoozed_until` in the future.
      def update(item_id, state:, snoozed_until: nil)
        body = compact_nil('state' => state, 'snoozedUntil' => iso8601(snoozed_until))
        InboxItem.new(unwrap(http.request(:patch, "/inbox/#{item_id}", json: body)))
      end

      # Edit a comment the account wrote, on the platform. Needs `publish`.
      def edit_comment(item_id, text:)
        InboxItem.new(unwrap(http.request(:patch, "/inbox/#{item_id}", json: { 'text' => text })))
      end

      # Send the reply on the platform as the connected account. `text` may be
      # left out when `media_ids` is given; `media_ids` and `quick_replies` need `publish`.
      def reply(item_id, text: nil, media_ids: nil, quick_replies: nil)
        body = compact_nil('text' => text, 'media_ids' => media_ids, 'quick_replies' => quick_replies)
        InboxReplyResult.new(unwrap(http.post("/inbox/#{item_id}/reply", body)))
      end

      def hide(item_id)
        InboxItem.new(unwrap(http.post("/inbox/#{item_id}/hide")))
      end

      def unhide(item_id)
        InboxItem.new(unwrap(http.post("/inbox/#{item_id}/unhide")))
      end

      # Delete the comment on the platform, or our own reply (that also needs `publish`).
      def delete(item_id)
        http.delete("/inbox/#{item_id}")
        nil
      end

      # Like the item (an upvote on Reddit, a favourite on Mastodon). Needs `publish`.
      def like(item_id)
        InboxItem.new(unwrap(http.post("/inbox/#{item_id}/like")))
      end

      def unlike(item_id)
        InboxItem.new(unwrap(http.post("/inbox/#{item_id}/unlike")))
      end

      # Pin our own comment. Needs `publish`.
      def pin(item_id)
        InboxItem.new(unwrap(http.post("/inbox/#{item_id}/pin")))
      end

      def unpin(item_id)
        InboxItem.new(unwrap(http.post("/inbox/#{item_id}/unpin")))
      end

      # React to a DM with an emoji; `nil` removes ours. Needs `publish`.
      def react(item_id, reaction:)
        InboxItem.new(unwrap(http.post("/inbox/#{item_id}/react", { 'reaction' => reaction })))
      end

      # Open a DM: by `handle` from `account_id`, or as a private reply to the
      # inbox comment `comment_id`. Needs `publish`.
      def start_conversation(text:, account_id: nil, handle: nil, comment_id: nil, media_ids: nil)
        body = compact_nil(
          'account_id' => account_id,
          'handle' => handle,
          'comment_id' => comment_id,
          'text' => text,
          'media_ids' => media_ids
        )
        InboxStartedConversation.new(unwrap(http.post('/inbox/conversations', body)))
      end

      # Show or clear the typing indicator in a DM thread. Returns whether it is on. Needs `publish`.
      def set_typing(conversation_id, account_id:, on: true)
        body = { 'account_id' => account_id, 'on' => on }
        as_hash(unwrap(http.post("/inbox/conversations/#{conversation_id}/typing", body)))['typing']
      end

      # Pass a Messenger thread to another Meta app, or take it back without an `app_id`.
      def handover(conversation_id, account_id:, app_id: nil, metadata: nil)
        body = { 'account_id' => account_id }
        body['app_id'] = app_id unless app_id.nil?
        body['metadata'] = metadata unless metadata.nil?
        InboxHandover.new(unwrap(http.post("/inbox/conversations/#{conversation_id}/handover", body)))
      end

      # Replies an automation or the agent drafted that a person still has to send.
      def approvals(workspace_id: nil)
        parse_list(InboxApproval, unwrap(http.get('/inbox/approvals', { 'workspace_id' => workspace_id })))
      end

      # Send the draft, or `text` in its place.
      def approve_reply(approval_id, text: nil)
        as_hash(unwrap(http.post("/inbox/approvals/#{approval_id}/approve", compact_nil('text' => text))))
      end

      def reject_reply(approval_id)
        as_hash(unwrap(http.post("/inbox/approvals/#{approval_id}/reject")))
      end

      private

      def page_of(model, body)
        items = parse_list(model, body.is_a?(Hash) ? body['data'] : body)
        raw_meta = body.is_a?(Hash) ? body['meta'] : nil
        Page.new(items: items, meta: InboxPageMeta.new(raw_meta.is_a?(Hash) ? raw_meta : {}))
      end
    end
  end
end
