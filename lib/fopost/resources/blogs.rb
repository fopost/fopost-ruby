# frozen_string_literal: true

module Fopost
  module Resources
    # `client.blogs` — content a connected site already owns.
    #
    # Most of this SDK creates content. These calls reach what is already
    # there: the articles on a WordPress site or a Shopify store's blog, and a
    # Shopify store's products. Every id here is the platform's own, never a
    # FoPost id.
    #
    # Reads need the `posts` scope. Anything that changes the site needs
    # `posts` and `publish`, because a change here is visible to the site's own
    # readers.
    class Blogs < Base
      # Blogs the account can write to. Shopify reports every blog on the
      # store; WordPress reports its one implicit blog, under the id `default`.
      def list_blogs(account_id)
        parse_list(RemoteBlog, unwrap(http.get("/accounts/#{account_id}/blogs")))
      end

      # Articles on the blog, newest first, drafts included.
      #
      # `status` is published, draft, pending or scheduled; `q` matches the
      # title; `limit` is 1 to 50.
      def list_articles(account_id, blog_id, limit: nil, status: nil, q: nil)
        params = compact_nil('limit' => limit, 'status' => status, 'q' => q)
        parse_list(
          RemoteArticle,
          unwrap(http.get("/accounts/#{account_id}/blogs/#{blog_id}/articles", params))
        )
      end

      def get_article(account_id, blog_id, article_id)
        RemoteArticle.new(
          unwrap(http.get("/accounts/#{account_id}/blogs/#{blog_id}/articles/#{article_id}"))
        )
      end

      # Write a new article to the blog. Needs the `publish` scope.
      #
      # `body` is FoPost body markup; the site's own format is rendered from it.
      def create_article(account_id, blog_id, title:, body:, excerpt: nil, status: nil,
                         tags: nil, author_name: nil, image_url: nil)
        payload = compact_nil(
          'title' => title,
          'body' => body,
          'excerpt' => excerpt,
          'status' => status,
          'tags' => tags&.to_a,
          'author_name' => author_name,
          'image_url' => image_url
        )
        RemoteArticle.new(
          unwrap(http.post("/accounts/#{account_id}/blogs/#{blog_id}/articles", payload))
        )
      end

      # Change the live article in place. Needs the `publish` scope.
      #
      # Only the keywords you pass are touched, and the article is addressed by
      # its own id, so an edit never creates a second post on the site. Pass at
      # least one field.
      def update_article(account_id, blog_id, article_id, title: UNSET, body: UNSET,
                         excerpt: UNSET, status: UNSET, tags: UNSET, author_name: UNSET,
                         image_url: UNSET)
        payload = compact_unset(
          'title' => title,
          'body' => body,
          'excerpt' => excerpt,
          'status' => status,
          'tags' => UNSET.equal?(tags) ? UNSET : tags&.to_a,
          'author_name' => author_name,
          'image_url' => image_url
        )
        RemoteArticle.new(
          unwrap(http.request(
                   :patch,
                   "/accounts/#{account_id}/blogs/#{blog_id}/articles/#{article_id}",
                   json: payload
                 ))
        )
      end

      # Remove the article from the site. Needs `publish`; cannot be undone.
      def delete_article(account_id, blog_id, article_id)
        http.delete("/accounts/#{account_id}/blogs/#{blog_id}/articles/#{article_id}")
        nil
      end

      # The store's products. `status` is active, draft or archived.
      def list_products(account_id, limit: nil, status: nil, q: nil)
        params = compact_nil('limit' => limit, 'status' => status, 'q' => q)
        parse_list(RemoteProduct, unwrap(http.get("/accounts/#{account_id}/products", params)))
      end

      # Change a product on the store. Needs `publish`; only what you pass changes.
      def update_product(account_id, product_id, title: UNSET, description: UNSET,
                         status: UNSET, tags: UNSET, product_type: UNSET, vendor: UNSET)
        payload = compact_unset(
          'title' => title,
          'description' => description,
          'status' => status,
          'tags' => UNSET.equal?(tags) ? UNSET : tags&.to_a,
          'product_type' => product_type,
          'vendor' => vendor
        )
        RemoteProduct.new(
          unwrap(http.request(:patch, "/accounts/#{account_id}/products/#{product_id}",
                              json: payload))
        )
      end
    end
  end
end
