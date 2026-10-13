# frozen_string_literal: true

require 'json'

module Fopost
  module Resources
    # `client.posts` — create, schedule, publish, and inspect posts.
    class Posts < Base
      # One page of posts. The result is Enumerable over its items.
      def list(workspace_id: nil, status: nil, search: nil, page: 1, per_page: 30, sort: nil)
        body = http.get(
          '/posts',
          {
            'workspace_id' => workspace_id,
            'status' => status,
            'search' => search,
            'page' => page,
            'per_page' => per_page,
            'sort' => sort
          }
        )

        items = parse_list(Post, body.is_a?(Hash) ? body['data'] : body)
        raw_meta = body.is_a?(Hash) ? body['meta'] : nil
        Page.new(items: items, meta: PageMeta.new(raw_meta.is_a?(Hash) ? raw_meta : {}))
      end

      # Walk every matching post, fetching one page at a time.
      def each(workspace_id: nil, status: nil, search: nil, per_page: 30, sort: nil, start_page: 1, &block)
        unless block
          return enum_for(:each, workspace_id: workspace_id, status: status, search: search,
                                 per_page: per_page, sort: sort, start_page: start_page)
        end

        each_page(workspace_id: workspace_id, status: status, search: search,
                  per_page: per_page, sort: sort, start_page: start_page) do |page|
          page.items.each(&block)
        end
      end

      # The same walk as {#each}, but yields whole pages so the meta stays reachable.
      def each_page(workspace_id: nil, status: nil, search: nil, per_page: 30, sort: nil, start_page: 1)
        unless block_given?
          return enum_for(:each_page, workspace_id: workspace_id, status: status, search: search,
                                      per_page: per_page, sort: sort, start_page: start_page)
        end

        page_number = start_page
        loop do
          page = list(workspace_id: workspace_id, status: status, search: search,
                      page: page_number, per_page: per_page, sort: sort)
          return if page.items.empty?

          yield page

          last_page = page.meta.last_page
          return if last_page && page_number >= last_page
          return if last_page.nil? && page.items.size < per_page

          page_number += 1
        end
      end

      def get(post_id)
        Post.new(unwrap(http.get("/posts/#{post_id}")))
      end

      # Create a draft or a scheduled post.
      #
      # `status` is "draft" or "scheduled"; a scheduled post needs `schedule_at`.
      # To send a post out now, create it and call {#publish}. `account_group_id`
      # adds that group's accounts to `accounts`, so `accounts` may be left empty.
      #
      # `files` (paths, IOs, or `{ filename:, io:/data:, mime_type: }` hashes) are
      # stored in the library and attached to the first block. Files over the
      # multipart ceiling go through direct upload; the result is the same.
      def create(workspace_id:, content:, accounts: [], account_group_id: nil, status: 'draft', schedule_at: nil,
                 labels: nil, title: nil, summary: nil, content_type: nil, settings: nil, files: nil, **extra)
        body = {
          'workspace_id' => workspace_id,
          'status' => status,
          'content' => normalize_content(content),
          'accounts' => normalize_accounts(accounts)
        }
        body.merge!(
          compact_nil(
            'account_group_id' => account_group_id,
            'schedule_at' => iso8601(schedule_at),
            'labels' => labels&.to_a,
            'title' => title,
            'summary' => summary,
            'content_type' => content_type,
            'settings' => settings
          )
        )
        body.merge!(stringify(extra))

        parts = file_parts(files)
        return Post.new(unwrap(http.post('/posts', body))) if parts.empty?

        if multipart_fits?(parts, workspace_id)
          fields = { 'post' => JSON.generate(body) }
          return Post.new(unwrap(http.post_multipart('/posts', fields: fields, parts: multipart_parts(parts))))
        end

        attach_media(body['content'], upload_parts(workspace_id, parts))
        Post.new(unwrap(http.post('/posts', body)))
      end

      # Partial update — only the fields you pass are sent. Pass an explicit nil
      # to clear a field.
      def update(post_id, content: UNSET, accounts: UNSET, status: UNSET, schedule_at: UNSET,
                 labels: UNSET, title: UNSET, summary: UNSET, content_type: UNSET,
                 settings: UNSET, files: nil, **extra)
        body = compact_unset(
          'content' => UNSET.equal?(content) ? UNSET : normalize_content(content),
          'accounts' => UNSET.equal?(accounts) ? UNSET : normalize_accounts(accounts),
          'status' => status,
          'schedule_at' => UNSET.equal?(schedule_at) ? UNSET : iso8601(schedule_at),
          'labels' => UNSET.equal?(labels) ? UNSET : labels&.to_a,
          'title' => title,
          'summary' => summary,
          'content_type' => content_type,
          'settings' => settings
        )
        body.merge!(stringify(extra))

        parts = file_parts(files)
        return Post.new(unwrap(http.put("/posts/#{post_id}", body))) if parts.empty?

        if multipart_fits?(parts, nil)
          fields = { 'post' => JSON.generate(body) }
          multipart = http.put_multipart("/posts/#{post_id}", fields: fields, parts: multipart_parts(parts))
          return Post.new(unwrap(multipart))
        end

        # The direct path needs the workspace, and the current blocks when none were given.
        existing = get(post_id)
        body['content'] = normalize_content(existing.content) unless body.key?('content')
        attach_media(body['content'], upload_parts(existing.workspace_id, parts))
        Post.new(unwrap(http.put("/posts/#{post_id}", body)))
      end

      def delete(post_id)
        http.delete("/posts/#{post_id}")
        nil
      end

      # Queue the post for immediate delivery to its accounts.
      def publish(post_id)
        as_hash(unwrap(http.post("/posts/#{post_id}/publish")))
      end

      def cancel(post_id)
        as_hash(unwrap(http.post("/posts/#{post_id}/cancel")))
      end

      # Retry the deliveries that failed, leaving the successful ones alone.
      def retry(post_id)
        as_hash(unwrap(http.post("/posts/#{post_id}/retry")))
      end

      # Per-account blockers and advisory content signals, without publishing.
      def preflight(post_id)
        as_hash(unwrap(http.post("/posts/#{post_id}/preflight")))
      end

      def deliveries(post_id)
        parse_list(Delivery, unwrap(http.get("/posts/#{post_id}/deliveries")))
      end

      private

      # Accept a bare string, one block, or an array of either.
      def normalize_content(content)
        blocks = content.is_a?(Array) ? content : [content]

        blocks.map do |block|
          case block
          when String then { 'text' => block }
          when ContentBlock
            {
              'text' => block.text,
              'media' => block.media.map { |item| compact_nil(stringify(item.to_h)) }
            }
          when Hash then compact_nil(stringify(block))
          else
            raise ArgumentError, "fopost: cannot read a content block from #{block.inspect}"
          end
        end
      end

      # The API takes bare account ids; also accept account objects or {"id" => ...}.
      def normalize_accounts(accounts)
        Array(accounts).map do |account|
          case account
          when String then account
          when SocialAccount then account.id
          when Hash
            id = account['id'] || account[:id]
            raise ArgumentError, "fopost: cannot read an account id from #{account.inspect}" unless id.is_a?(String)

            id
          else
            raise ArgumentError, "fopost: cannot read an account id from #{account.inspect}"
          end
        end
      end

      def stringify(hash)
        hash.each_with_object({}) { |(key, value), out| out[key.to_s] = value }
      end

      def file_parts(files)
        Array(files).map { |file| FilePart.from(file) }
      end

      # One multipart request when every file fits its per-file ceiling.
      def multipart_fits?(parts, workspace_id)
        ceiling = begin
          media.limits(workspace_id: workspace_id).multipart_max_file_bytes
        rescue Error
          nil
        end
        ceiling = Media::DEFAULT_MULTIPART_MAX_FILE_BYTES unless ceiling.is_a?(Integer)
        parts.all? { |part| part.size <= ceiling }
      end

      def multipart_parts(parts)
        parts.map do |part|
          HTTP::Multipart::Part.new(name: 'files', filename: part.filename, mime_type: part.mime_type,
                                    data: part.data)
        end
      end

      def upload_parts(workspace_id, parts)
        parts.map do |part|
          item = media.upload_direct(workspace_id: workspace_id, filename: part.filename,
                                     mime_type: part.mime_type, data: part.data)
          compact_nil('type' => part.media_type, 'name' => item.name || part.filename, 'url' => item.url,
                      'size' => item.size || part.size)
        end
      end

      def attach_media(blocks, items)
        blocks << {} if blocks.empty?
        first = blocks.first
        first['media'] = Array(first['media']) + items
      end

      def media
        @media ||= Media.new(http)
      end
    end
  end
end
