# frozen_string_literal: true

module Fopost
  module Resources
    # `client.accounts` — the social accounts connected to a workspace.
    class Accounts < Base
      # Connected accounts, across every workspace unless one is named.
      def list(workspace_id: nil, group_id: nil)
        # This endpoint reads a camelCase workspaceId; posts and labels use snake.
        params = { 'workspaceId' => workspace_id, 'group_id' => group_id }
        parse_list(SocialAccount, unwrap(http.get('/accounts', params)))
      end

      def get(account_id)
        SocialAccount.new(unwrap(http.get("/accounts/#{account_id}")))
      end

      # Token validity and last-check detail for one account.
      def health(account_id)
        as_hash(unwrap(http.get("/accounts/#{account_id}/health")))
      end

      # Rename the account; nil or an empty string restores the platform name.
      def update(account_id, display_name:)
        body = { 'display_name' => display_name }
        AccountRename.new(unwrap(http.request(:patch, "/accounts/#{account_id}", json: body)))
      end

      # Move the account to another workspace the caller owns.
      def move(account_id, workspace_id:)
        AccountMove.new(unwrap(http.post("/accounts/#{account_id}/move", { 'workspace_id' => workspace_id })))
      end

      # Mint a 15-minute code; sending `/connect <code>` to the bot connects that chat.
      # workspace_id may be omitted for a key bound to one workspace.
      def create_telegram_connect_code(workspace_id: nil)
        TelegramConnectCode.new(unwrap(http.post('/accounts/telegram/connect-code',
                                                 compact_nil({ 'workspaceId' => workspace_id }))))
      end

      def get_telegram_connect_status(code)
        TelegramConnectStatus.new(unwrap(http.get('/accounts/telegram/connect-code/status', { 'code' => code })))
      end

      def get_telegram_bot_commands(account_id)
        TelegramBotCommands.new(unwrap(http.get("/accounts/#{account_id}/telegram/commands")))
      end

      # Replace the chat's command menu; each entry is a hash with `command` and `description`.
      def set_telegram_bot_commands(account_id, commands)
        body = {
          'commands' => commands.map do |entry|
            { 'command' => entry[:command] || entry['command'],
              'description' => entry[:description] || entry['description'] }
          end
        }
        TelegramBotCommands.new(unwrap(http.put("/accounts/#{account_id}/telegram/commands", body)))
      end

      def delete_telegram_bot_commands(account_id)
        TelegramBotCommands.new(unwrap(http.delete("/accounts/#{account_id}/telegram/commands")))
      end

      # Channels the Slack app can post to in the connected workspace.
      def list_slack_channels(account_id)
        parse_list(SlackChannel, unwrap(http.get("/accounts/#{account_id}/slack/channels")))
      end

      # People in the connected Slack workspace; a member's `id` is the handle for starting a DM.
      def list_slack_members(account_id)
        parse_list(SlackMember, unwrap(http.get("/accounts/#{account_id}/slack/members")))
      end

      def get_slack_identity(account_id)
        SlackIdentity.new(unwrap(http.get("/accounts/#{account_id}/slack/identity")))
      end

      # Set the posting name and icon: an omitted keyword keeps a field, nil clears it.
      def update_slack_identity(account_id, username: UNSET, icon_url: UNSET, icon_emoji: UNSET)
        body = compact_unset({ 'username' => username, 'icon_url' => icon_url, 'icon_emoji' => icon_emoji })
        SlackIdentity.new(unwrap(http.request(:patch, "/accounts/#{account_id}/slack/identity", json: body)))
      end

      # ── Meta messaging settings (Facebook Pages, Instagram) ──────

      # The prompts shown before the first message; networks without them answer 400.
      def get_ice_breakers(account_id)
        MetaIceBreakers.new(unwrap(http.get("/accounts/#{account_id}/messaging/ice-breakers")))
      end

      # Replace the ice breakers, up to four; each entry has `question` and `payload`.
      def set_ice_breakers(account_id, ice_breakers)
        body = {
          'ice_breakers' => ice_breakers.map do |entry|
            { 'question' => entry[:question] || entry['question'],
              'payload' => entry[:payload] || entry['payload'] }
          end
        }
        MetaIceBreakers.new(unwrap(http.put("/accounts/#{account_id}/messaging/ice-breakers", body)))
      end

      def delete_ice_breakers(account_id)
        MetaIceBreakers.new(unwrap(http.delete("/accounts/#{account_id}/messaging/ice-breakers")))
      end

      # The always-visible Messenger menu. Facebook Pages only.
      def get_persistent_menu(account_id)
        MetaPersistentMenu.new(unwrap(http.get("/accounts/#{account_id}/messaging/persistent-menu")))
      end

      # Replace the menu, one entry per locale, up to three items each.
      def set_persistent_menu(account_id, menu)
        body = { 'persistent_menu' => menu.map { |entry| stringify(entry) } }
        MetaPersistentMenu.new(unwrap(http.put("/accounts/#{account_id}/messaging/persistent-menu", body)))
      end

      def delete_persistent_menu(account_id)
        MetaPersistentMenu.new(unwrap(http.delete("/accounts/#{account_id}/messaging/persistent-menu")))
      end

      # The text shown before a Messenger conversation starts. Facebook Pages only.
      def get_greeting(account_id)
        MetaGreeting.new(unwrap(http.get("/accounts/#{account_id}/messaging/greeting")))
      end

      # Replace the greeting, one entry per locale, each up to 160 characters.
      def set_greeting(account_id, greeting)
        body = {
          'greeting' => greeting.map do |entry|
            { 'locale' => entry[:locale] || entry['locale'] || 'default',
              'text' => entry[:text] || entry['text'] }
          end
        }
        MetaGreeting.new(unwrap(http.put("/accounts/#{account_id}/messaging/greeting", body)))
      end

      def delete_greeting(account_id)
        MetaGreeting.new(unwrap(http.delete("/accounts/#{account_id}/messaging/greeting")))
      end

      # What the network is delivering to the FoPost webhook for this account.
      def get_webhook_subscription(account_id)
        WebhookSubscription.new(unwrap(http.get("/accounts/#{account_id}/webhook-subscription")))
      end

      # Subscribe to every field this account needs, lapsed or not.
      def resubscribe_webhook(account_id)
        WebhookSubscription.new(unwrap(http.post("/accounts/#{account_id}/webhook-subscription")))
      end

      private

      # Symbol keys read the same as string keys on the way out to the API.
      def stringify(value)
        case value
        when Hash then value.to_h { |k, v| [k.to_s, stringify(v)] }
        when Array then value.map { |v| stringify(v) }
        else value
        end
      end
    end
  end
end
