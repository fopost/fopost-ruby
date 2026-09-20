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

      # ── Discord (bot connections; a webhook one answers 409 webhook_connection) ──

      # Text channels the bot can post to in the connected server.
      def list_discord_channels(account_id)
        parse_list(DiscordChannel, unwrap(http.get("/accounts/#{account_id}/discord/channels")))
      end

      # Move the account to another channel in the same server.
      def switch_discord_channel(account_id, channel_id)
        body = { 'channel_id' => channel_id }
        path = "/accounts/#{account_id}/discord/channels/current"
        DiscordChannel.new(unwrap(http.request(:patch, path, json: body)))
      end

      def get_discord_identity(account_id)
        DiscordIdentity.new(unwrap(http.get("/accounts/#{account_id}/discord/identity")))
      end

      # Set the bot's nickname and avatar: an omitted keyword keeps a field, nil clears it.
      def update_discord_identity(account_id, username: UNSET, avatar_url: UNSET)
        body = compact_unset({ 'username' => username, 'avatar_url' => avatar_url })
        path = "/accounts/#{account_id}/discord/identity"
        DiscordIdentity.new(unwrap(http.request(:patch, path, json: body)))
      end

      # Pinned messages in the account's channel.
      def list_discord_pins(account_id)
        parse_list(DiscordMessage, unwrap(http.get("/accounts/#{account_id}/discord/messages/pinned")))
      end

      def delete_discord_message(account_id, message_id)
        http.delete("/accounts/#{account_id}/discord/messages/#{message_id}")
        nil
      end

      def pin_discord_message(account_id, message_id)
        http.post("/accounts/#{account_id}/discord/messages/#{message_id}/pin")
        nil
      end

      def unpin_discord_message(account_id, message_id)
        http.delete("/accounts/#{account_id}/discord/messages/#{message_id}/pin")
        nil
      end

      # Publish an announcement-channel message to every server following it.
      def crosspost_discord_message(account_id, message_id)
        path = "/accounts/#{account_id}/discord/messages/#{message_id}/crosspost"
        DiscordMessageRef.new(unwrap(http.post(path)))
      end

      # Start a thread on a message; the duration is 60, 1440, 4320 or 10_080 minutes.
      def create_discord_thread(account_id, message_id, name:, auto_archive_duration: nil)
        body = compact_nil({ 'name' => name, 'auto_archive_duration' => auto_archive_duration })
        path = "/accounts/#{account_id}/discord/messages/#{message_id}/thread"
        DiscordThread.new(unwrap(http.post(path, body)))
      end

      # Send one message to a member of the server.
      def send_discord_dm(account_id, member_id, content)
        body = { 'member_id' => member_id, 'content' => content }
        DiscordMessageRef.new(unwrap(http.post("/accounts/#{account_id}/discord/dm", body)))
      end

      # The server's scheduled events.
      def list_discord_events(account_id)
        parse_list(DiscordScheduledEvent, unwrap(http.get("/accounts/#{account_id}/discord/events")))
      end

      def get_discord_event(account_id, event_id)
        DiscordScheduledEvent.new(unwrap(http.get("/accounts/#{account_id}/discord/events/#{event_id}")))
      end

      # Give a `channel_id` (a voice or stage channel), or a `location` with an `end_time`.
      def create_discord_event(account_id, name:, start_time:, end_time: nil, description: nil,
                               channel_id: nil, location: nil)
        body = compact_nil({
                             'name' => name, 'start_time' => start_time, 'end_time' => end_time,
                             'description' => description, 'channel_id' => channel_id, 'location' => location
                           })
        DiscordScheduledEvent.new(unwrap(http.post("/accounts/#{account_id}/discord/events", body)))
      end

      # Only the keywords you pass are sent; Discord keeps the rest.
      def update_discord_event(account_id, event_id, name: nil, start_time: nil, end_time: nil,
                               description: nil, channel_id: nil, location: nil, status: nil)
        body = compact_nil({
                             'name' => name, 'start_time' => start_time, 'end_time' => end_time,
                             'description' => description, 'channel_id' => channel_id,
                             'location' => location, 'status' => status
                           })
        path = "/accounts/#{account_id}/discord/events/#{event_id}"
        DiscordScheduledEvent.new(unwrap(http.request(:patch, path, json: body)))
      end

      def delete_discord_event(account_id, event_id)
        http.delete("/accounts/#{account_id}/discord/events/#{event_id}")
        nil
      end

      # The server's roster, or the members whose name starts with `query`.
      def list_discord_members(account_id, query: nil, limit: nil)
        params = compact_nil({ 'q' => query, 'limit' => limit })
        parse_list(DiscordMember, unwrap(http.get("/accounts/#{account_id}/discord/members", params)))
      end

      def get_discord_member(account_id, member_id)
        DiscordMember.new(unwrap(http.get("/accounts/#{account_id}/discord/members/#{member_id}")))
      end

      # The server's roles, highest first.
      def list_discord_roles(account_id)
        parse_list(DiscordRole, unwrap(http.get("/accounts/#{account_id}/discord/roles")))
      end

      def create_discord_role(account_id, name:, color: nil, hoist: nil, mentionable: nil, permissions: nil)
        body = discord_role_body(name, color, hoist, mentionable, permissions)
        DiscordRole.new(unwrap(http.post("/accounts/#{account_id}/discord/roles", body)))
      end

      def update_discord_role(account_id, role_id, name: nil, color: nil, hoist: nil,
                              mentionable: nil, permissions: nil)
        body = discord_role_body(name, color, hoist, mentionable, permissions)
        path = "/accounts/#{account_id}/discord/roles/#{role_id}"
        DiscordRole.new(unwrap(http.request(:patch, path, json: body)))
      end

      def delete_discord_role(account_id, role_id)
        http.delete("/accounts/#{account_id}/discord/roles/#{role_id}")
        nil
      end

      def add_discord_member_role(account_id, role_id, member_id)
        http.put("/accounts/#{account_id}/discord/roles/#{role_id}/members/#{member_id}")
        nil
      end

      def remove_discord_member_role(account_id, role_id, member_id)
        http.delete("/accounts/#{account_id}/discord/roles/#{role_id}/members/#{member_id}")
        nil
      end

      private

      def discord_role_body(name, color, hoist, mentionable, permissions)
        compact_nil({
                      'name' => name, 'color' => color, 'hoist' => hoist,
                      'mentionable' => mentionable, 'permissions' => permissions
                    })
      end
    end
  end
end
