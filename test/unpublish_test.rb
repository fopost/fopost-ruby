# frozen_string_literal: true

require 'test_helper'

class UnpublishTest < Minitest::Test
  include ClientHelpers

  def test_unpublish_takes_the_post_down
    transport.stub(:post, '/posts/post_1/unpublish', json: {
                     'post_status' => 'unpublished',
                     'deliveries' => [
                       { 'account_id' => 'acc_1', 'platform' => 'twitter', 'removed' => true },
                       { 'account_id' => 'acc_2', 'platform' => 'tiktok', 'removed' => false }
                     ]
                   })

    result = client.posts.unpublish('post_1')

    assert_equal 'POST', transport.last.method
    assert_equal '/v1/posts/post_1/unpublish', transport.last.path
    assert_nil transport.last.body
    assert_equal 'unpublished', result.post_status
    assert result.deliveries[0].removed
    refute result.deliveries[1].removed
  end
end
