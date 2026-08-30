# frozen_string_literal: true

# Create a post and publish it.
#
# Point it at a local dev API:
#
#     export FOPOST_API_KEY=fp_...
#     export FOPOST_BASE_URL=http://localhost:8080/v1
#     ruby examples/create_post.rb "Hello from the Ruby SDK"
#
# Without --publish it stops at a draft, so you can run it against a real
# workspace without anything going out.

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'fopost'

def main(argv)
  publish = argv.delete('--publish')
  workspace_id = (index = argv.index('--workspace')) ? argv.slice!(index, 2)[1] : nil
  text = argv.first || 'Hello from the FoPost Ruby SDK'

  api_key = ENV['FOPOST_API_KEY']
  unless api_key
    warn 'Set FOPOST_API_KEY first.'
    return 1
  end

  client = Fopost.new(api_key: api_key, base_url: ENV.fetch('FOPOST_BASE_URL', Fopost::DEFAULT_BASE_URL))

  unless workspace_id
    workspace = client.workspaces.list.first
    unless workspace
      warn 'No workspaces on this key.'
      return 1
    end
    workspace_id = workspace.id
    puts "Workspace: #{workspace.name} (#{workspace_id})"
  end

  accounts = client.accounts.list(workspace_id: workspace_id)
  if accounts.empty?
    warn 'No connected accounts in this workspace.'
    return 1
  end
  accounts.each { |account| puts "  · #{account.platform}: @#{account.username}" }

  post = client.posts.create(workspace_id: workspace_id, content: text, accounts: accounts.map(&:id))
  puts "Created post #{post.id} (#{post.status})"

  if publish
    client.posts.publish(post.id)
    client.posts.deliveries(post.id).each { |d| puts "  · #{d.platform}: #{d.status}" }
  end

  0
rescue Fopost::Error => e
  warn "API error: #{e}"
  1
end

exit(main(ARGV)) if $PROGRAM_NAME == __FILE__
