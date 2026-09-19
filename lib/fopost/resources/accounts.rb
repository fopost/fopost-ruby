# frozen_string_literal: true

require 'cgi'

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

      # Subreddits the account is in, busiest first, plus its own profile page.
      def list_reddit_subreddits(account_id)
        parse_list(RedditSubreddit, unwrap(http.get("/accounts/#{account_id}/reddit/subreddits")))
      end

      # The rules a subreddit publishes, in its own order.
      def list_reddit_subreddit_rules(account_id, subreddit)
        path = "/accounts/#{account_id}/reddit/subreddits/#{CGI.escape(subreddit)}/rules"
        RedditSubredditRules.new(unwrap(http.get(path)))
      end

      # Post flairs one subreddit offers; a flair id is valid only there.
      def list_reddit_flairs(account_id, subreddit)
        RedditFlairs.new(
          unwrap(http.get("/accounts/#{account_id}/reddit/flairs", { 'subreddit' => subreddit }))
        )
      end

      # Where posts go when a post names none; nil falls back to the profile page.
      def set_reddit_default_subreddit(account_id, subreddit)
        RedditDefaultSubreddit.new(
          unwrap(http.put("/accounts/#{account_id}/reddit/default-subreddit", { 'subreddit' => subreddit }))
        )
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
    end
  end
end
