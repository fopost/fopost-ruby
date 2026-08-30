# frozen_string_literal: true

require 'test_helper'

class ModelsTest < Minitest::Test
  def test_either_wire_casing_parses
    snake = Fopost::SocialAccount.new('workspace_id' => 'ws_1', 'is_primary' => true)
    camel = Fopost::SocialAccount.new('workspaceId' => 'ws_1', 'isPrimary' => true)

    assert_equal 'ws_1', snake.workspace_id
    assert_equal 'ws_1', camel.workspace_id
    assert camel.is_primary
  end

  def test_an_unknown_field_survives_on_raw
    post = Fopost::Post.new(POST_FIXTURE.merge('somethingNew' => 42))

    assert_equal 42, post['somethingNew']
    assert_equal 42, post['something_new']
    assert_equal 42, post.raw['somethingNew']
  end

  def test_missing_collections_default_to_empty
    post = Fopost::Post.new('id' => 'post_1', 'status' => 'draft')

    assert_equal [], post.content
    assert_equal [], post.accounts
    assert_equal({}, post.settings)
    assert_nil post.schedule_at
  end

  def test_nested_models_are_built
    post = Fopost::Post.new(POST_FIXTURE)

    assert_instance_of Fopost::ContentBlock, post.content[0]
    assert_instance_of Fopost::PostAccount, post.accounts[0]
    assert_equal 'twitter', post.accounts[0].platform
  end

  def test_media_is_parsed_inside_a_block
    block = Fopost::ContentBlock.new(
      'text' => 'With an image',
      'media' => [{ 'type' => 'image', 'name' => 'chart.png', 'url' => 'https://example.test/chart.png' }]
    )

    assert_instance_of Fopost::MediaItem, block.media[0]
    assert_equal 'image', block.media[0].type
  end

  def test_a_garbled_timestamp_is_nil_rather_than_a_raise
    assert_nil Fopost::Post.new('created_at' => 'not a date').created_at
  end

  def test_page_is_enumerable
    page = Fopost::Page.new(items: [Fopost::Post.new(POST_FIXTURE)], meta: Fopost::PageMeta.new('total' => 1))

    assert_equal 1, page.size
    assert_equal ['post_1'], page.map(&:id)
    refute_predicate page, :empty?
    assert_equal 1, page.meta.total
  end

  def test_models_compare_by_payload
    assert_equal Fopost::Post.new(POST_FIXTURE), Fopost::Post.new(POST_FIXTURE)
    refute_equal Fopost::Post.new(POST_FIXTURE), Fopost::Post.new(POST_FIXTURE.merge('id' => 'post_2'))
  end

  def test_platform_and_status_lists_are_frozen
    assert_includes Fopost::PLATFORMS, 'twitter'
    assert_includes Fopost::POST_STATUSES, 'scheduled'
    assert_predicate Fopost::PLATFORMS, :frozen?
  end
end
