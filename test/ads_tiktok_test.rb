# frozen_string_literal: true

require 'test_helper'

class AdsTikTokTest < Minitest::Test
  include ClientHelpers

  def test_identities_and_spark_posts_read_the_right_paths
    transport
      .stub(:get, '/ads/tiktok/business-centers',
            json: { 'data' => [{ 'id' => 'bc1', 'name' => 'Brand HQ', 'role' => 'ADMIN' }] })
      .stub(:get, '/ads/tiktok/identities',
            json: { 'data' => [{ 'id' => 'idt_1', 'type' => 'CUSTOMIZED_USER', 'name' => 'Your Brand' }] })
      .stub(:get, '/ads/spark-posts',
            json: { 'data' => [{ 'id' => 'item_99', 'identityId' => 'idt_1', 'views' => 48_213 }] })

    centers = client.ads.tiktok_business_centers(workspace_id: 'ws_1', connection_id: 'conn_1')

    assert_equal 'Brand HQ', centers[0].name

    identities = client.ads.tiktok_identities(workspace_id: 'ws_1', connection_id: 'conn_1',
                                              ad_account_id: '7011')

    assert_equal 'CUSTOMIZED_USER', identities[0].type

    posts = client.ads.spark_posts(workspace_id: 'ws_1', connection_id: 'conn_1',
                                   ad_account_id: '7011', identity_id: 'idt_1')

    assert_equal 48_213, posts[0].views
    assert_equal 'idt_1', transport.last.query['identity_id']
  end

  def test_spark_post_id_and_smart_plus_travel_in_the_body
    transport
      .stub(:post, '/ads', json: { 'data' => AdsTest::AD_FIXTURE })
      .stub(:post, '/ads/campaigns', json: { 'data' => { 'id' => 'c1', 'name' => 'Smart', 'status' => 'PAUSED' } })

    client.ads.create(workspace_id: 'ws_1', connection_id: 'conn_1', ad_account_id: '7011',
                      page_id: 'idt_1', name: 'Spark', goal: 'traffic',
                      budget: { 'minor' => 2000, 'type' => 'daily' },
                      targeting: { 'countries' => ['US'] }, text: '', spark_post_id: 'item_99')

    assert_equal 'item_99', transport.last.json['sparkPostId']

    client.ads.create_campaign(workspace_id: 'ws_1', connection_id: 'conn_1', ad_account_id: '7011',
                               name: 'Smart', goal: 'traffic', smart_plus: true)

    assert_equal true, transport.last.json['smartPlus']
  end

  def test_conversions_report_what_the_network_accepted
    transport.stub(:post, '/ads/conversions', json: { 'data' => { 'accepted' => 1 } })

    result = client.ads.upload_conversions(
      workspace_id: 'ws_1', connection_id: 'conn_1', ad_account_id: '7011', pixel_id: 'px_1',
      events: [{ 'eventName' => 'CompletePayment', 'occurredAt' => '2026-09-18T10:04:00Z' }]
    )

    assert_equal 1, result['accepted']
    assert_equal 'px_1', transport.last.json['pixelId']
  end

  def test_comments_page_and_the_three_writes
    transport
      .stub(:get, '/ads/comments',
            json: { 'data' => { 'comments' => [{ 'id' => 'cm_1', 'text' => 'nice', 'likes' => 3,
                                                 'hidden' => true }],
                                'nextCursor' => '2' } })
      .stub(:post, '/ads/comments/cm_1/reply', json: { 'data' => { 'replyId' => 'cm_2' } })
      .stub(:post, '/ads/comments/cm_1/hide', json: { 'message' => 'Comment hidden' })
      .stub(:delete, '/ads/comments/cm_1', json: { 'message' => 'Comment deleted' })

    page = client.ads.comments(workspace_id: 'ws_1', connection_id: 'conn_1', ad_id: 'ad_1')

    assert_equal '2', page.next_cursor
    assert_equal true, page.comments[0].hidden
    assert_equal 3, page.comments[0].likes

    scope = { workspace_id: 'ws_1', connection_id: 'conn_1', ad_id: 'ad_1' }

    assert_equal 'cm_2', client.ads.reply_to_comment('cm_1', text: 'Friday!', **scope)['replyId']
    assert_equal 'ad_1', transport.last.json['adId']

    client.ads.set_comment_hidden('cm_1', hidden: true, **scope)

    assert_equal true, transport.last.json['hidden']

    client.ads.delete_comment('cm_1', **scope)
    # The ad travels in the body, because the path already carries the comment.
    assert_equal 'ad_1', transport.last.json['adId']
  end
end
