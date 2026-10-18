# frozen_string_literal: true

require 'test_helper'

class BlogsTest < Minitest::Test
  include ClientHelpers

  ARTICLE = {
    'id' => '99',
    'blog_id' => '11',
    'title' => 'Spring drop',
    'body_html' => '<p>Hello</p>',
    'excerpt' => 'A short summary',
    'status' => 'published',
    'author_name' => 'Store Owner',
    'tags' => ['news'],
    'image_url' => nil,
    'url' => 'https://demo.myshopify.com/blogs/article/spring-drop',
    'published_at' => '2026-09-01T10:00:00Z',
    'updated_at' => nil
  }.freeze

  def test_list_blogs_reads_every_blog_on_the_site
    transport.stub(:get, '/accounts/a1/blogs', json: {
                     'data' => [{ 'id' => '11', 'title' => 'News', 'handle' => 'news', 'url' => nil }]
                   })

    blogs = client.blogs.list_blogs('a1')

    assert_equal '/v1/accounts/a1/blogs', transport.last.path
    assert_equal 1, blogs.length
    assert_equal '11', blogs.first.id
    assert_equal 'News', blogs.first.title
  end

  def test_list_articles_passes_the_filters
    transport.stub(:get, '/accounts/a1/blogs/11/articles', json: { 'data' => [ARTICLE] })

    articles = client.blogs.list_articles('a1', '11', limit: 5, status: 'draft', q: 'spring')

    assert_equal({ 'limit' => '5', 'status' => 'draft', 'q' => 'spring' }, transport.last.query)
    assert_equal '99', articles.first.id
    assert_equal ['news'], articles.first.tags
    assert_equal 'Store Owner', articles.first.author_name
  end

  def test_update_article_changes_it_in_place
    transport.stub(:patch, '/accounts/a1/blogs/11/articles/99', json: { 'data' => ARTICLE })

    client.blogs.update_article('a1', '11', '99', title: 'Spring drop, restocked')

    # The article id is in the path, which is what stops an edit from creating
    # a second post on the site.
    assert_equal '/v1/accounts/a1/blogs/11/articles/99', transport.last.path
    # Only what the caller named travels, so nothing else is blanked.
    assert_equal({ 'title' => 'Spring drop, restocked' }, transport.last.json)
  end

  def test_create_article_omits_what_it_was_not_given
    transport.stub(:post, '/accounts/a1/blogs/11/articles', json: { 'data' => ARTICLE })

    client.blogs.create_article('a1', '11', title: 'Spring drop', body: 'Hello', status: 'draft')

    assert_equal({ 'title' => 'Spring drop', 'body' => 'Hello', 'status' => 'draft' },
                 transport.last.json)
  end

  def test_delete_article_hits_the_article_route
    transport.stub(:delete, '/accounts/a1/blogs/11/articles/99', status: 204, json: nil)

    client.blogs.delete_article('a1', '11', '99')

    assert_equal '/v1/accounts/a1/blogs/11/articles/99', transport.last.path
  end

  def test_update_product_sends_only_what_changed
    transport.stub(:patch, '/accounts/a1/products/7', json: {
                     'data' => {
                       'id' => '7', 'title' => 'Mug XL', 'handle' => 'mug', 'status' => 'draft',
                       'description' => nil, 'vendor' => nil, 'product_type' => 'Drinkware',
                       'tags' => [], 'image_url' => nil, 'url' => nil, 'price' => '12.00',
                       'currency' => 'USD', 'updated_at' => nil
                     }
                   })

    product = client.blogs.update_product('a1', '7', title: 'Mug XL', product_type: 'Drinkware')

    assert_equal({ 'title' => 'Mug XL', 'product_type' => 'Drinkware' }, transport.last.json)
    assert_equal '12.00', product.price
  end
end
