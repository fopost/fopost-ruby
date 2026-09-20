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

      # --- Per-network extras -------------------------------------

      # Boards this Pinterest connection can pin to.
      def list_pinterest_boards(account_id)
        parse_list(PinterestBoard, unwrap(http.get("/accounts/#{account_id}/pinterest/boards")))
      end

      # `privacy` is PUBLIC, PROTECTED or SECRET.
      def create_pinterest_board(account_id, name:, description: UNSET, privacy: UNSET)
        body = compact_unset({ 'name' => name, 'description' => description, 'privacy' => privacy })
        PinterestBoard.new(unwrap(http.post("/accounts/#{account_id}/pinterest/boards", body)))
      end

      # The channel's own playlists, with the stored default marked.
      def list_youtube_playlists(account_id)
        parse_list(YouTubePlaylist, unwrap(http.get("/accounts/#{account_id}/youtube/playlists")))
      end

      def create_youtube_playlist(account_id, title:, description: UNSET, privacy: UNSET)
        body = compact_unset({ 'title' => title, 'description' => description, 'privacy' => privacy })
        YouTubePlaylist.new(unwrap(http.post("/accounts/#{account_id}/youtube/playlists", body)))
      end

      # The playlist a new video joins when the post picks none; nil clears it.
      def set_default_youtube_playlist(account_id, playlist_id)
        data = unwrap(http.put("/accounts/#{account_id}/youtube/playlists/default",
                               { 'playlist_id' => playlist_id }))
        data.is_a?(Hash) ? data['playlist_id'] : nil
      end

      def list_youtube_captions(account_id, video_id)
        parse_list(YouTubeCaptionTrack,
                   unwrap(http.get("/accounts/#{account_id}/youtube/videos/#{video_id}/captions")))
      end

      # `body` is the subtitle file itself; YouTube reads SRT and WebVTT and sniffs which.
      def upload_youtube_captions(account_id, video_id, language:, body:, name: UNSET, is_draft: UNSET)
        payload = compact_unset({ 'language' => language, 'body' => body, 'name' => name,
                                  'is_draft' => is_draft })
        YouTubeCaptionTrack.new(
          unwrap(http.post("/accounts/#{account_id}/youtube/videos/#{video_id}/captions", payload))
        )
      end

      def read_youtube_transcript(account_id, caption_id)
        YouTubeTranscript.new(unwrap(http.get("/accounts/#{account_id}/youtube/captions/#{caption_id}")))
      end

      # What a post from this connection is written in when it does not say.
      def get_bluesky_languages(account_id)
        BlueskyLanguages.new(unwrap(http.get("/accounts/#{account_id}/bluesky/languages")))
      end

      # Up to three BCP-47 tags; an empty list clears the default.
      def set_bluesky_languages(account_id, languages)
        BlueskyLanguages.new(
          unwrap(http.put("/accounts/#{account_id}/bluesky/languages", { 'languages' => Array(languages) }))
        )
      end

      # The switches TikTok enforces at publish time, changed in the TikTok app.
      def get_tiktok_creator_info(account_id)
        TikTokCreatorInfo.new(unwrap(http.get("/accounts/#{account_id}/tiktok/creator-info")))
      end

      # TikTok's Commercial Music Library. Needs the Marketing API product on
      # the TikTok app; without it the call raises rather than answering empty.
      def search_tiktok_music(account_id, q:, limit: nil)
        params = { 'q' => q, 'limit' => limit }.compact
        parse_list(TikTokMusic, unwrap(http.get("/accounts/#{account_id}/tiktok/music", params)))
      end

      # Places a post can be tagged with. Same TikTok product as the music library.
      def search_tiktok_locations(account_id, q:, limit: nil)
        params = { 'q' => q, 'limit' => limit }.compact
        parse_list(TikTokPlace, unwrap(http.get("/accounts/#{account_id}/tiktok/locations", params)))
      end

      # Resolve a share link to one of this account's own videos, for repurposing.
      def lookup_tiktok_video(account_id, url)
        TikTokVideoSource.new(
          unwrap(http.post("/accounts/#{account_id}/tiktok/video-download", { 'url' => url }))
        )
      end

      # Tracks a Reel can carry; with no query Instagram answers with what is trending.
      def search_instagram_audio(account_id, q: nil, audio_type: nil)
        params = { 'q' => q, 'audio_type' => audio_type }.compact
        parse_list(InstagramAudio, unwrap(http.get("/accounts/#{account_id}/instagram/audio", params)))
      end

      # How many posts are left before Instagram refuses the next one.
      def get_instagram_publishing_limit(account_id)
        InstagramPublishingLimit.new(unwrap(http.get("/accounts/#{account_id}/instagram/publishing-limit")))
      end

      # Stories still inside their 24 hours, posted through FoPost or not.
      def list_instagram_stories(account_id, insights: nil)
        params = insights.nil? ? {} : { 'insights' => insights }
        parse_list(InstagramStory, unwrap(http.get("/accounts/#{account_id}/instagram/stories", params)))
      end

      def get_instagram_story_insights(account_id, story_id)
        InstagramStoryInsights.new(
          unwrap(http.get("/accounts/#{account_id}/instagram/stories/#{story_id}/insights"))
        )
      end

      # Organizations a LinkedIn post can mention. People are not searchable.
      def search_linkedin_mentions(account_id, q)
        parse_list(LinkedInMention, unwrap(http.get("/accounts/#{account_id}/linkedin/mentions", { 'q' => q })))
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

      def discord_role_body(name, color, hoist, mentionable, permissions)
        compact_nil({
                      'name' => name, 'color' => color, 'hoist' => hoist,
                      'mentionable' => mentionable, 'permissions' => permissions
                    })
      end
    end
  end
end
