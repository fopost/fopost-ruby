# frozen_string_literal: true

require 'test_helper'

class BulkImportTest < Minitest::Test
  include ClientHelpers

  CSV = "content,schedule_at\nHello,2026-11-01T10:00:00Z\n"

  def test_validate_sends_the_csv_as_multipart
    transport.stub(:post, '/posts/bulk-import/validate', json: {
                     'total_rows' => 1, 'valid_rows' => 1, 'invalid_rows' => 0, 'max_rows' => 500,
                     'rows' => [{ 'row' => 1, 'content_preview' => 'Hello', 'content_type' => 'post',
                                  'schedule_at' => '2026-11-01T10:00:00.000Z', 'accounts' => ['acc_1'],
                                  'errors' => [] }]
                   })

    result = client.posts.validate_bulk_import(workspace_id: 'ws_1',
                                               file: { filename: 'posts.csv', data: CSV, mime_type: 'text/csv' })

    assert_equal 'POST', transport.last.method
    assert_match %r{\Amultipart/form-data; boundary=}, transport.last.headers['Content-Type']
    assert_includes transport.last.body, 'name="workspace_id"'
    assert_includes transport.last.body, 'ws_1'
    assert_includes transport.last.body, 'name="file"; filename="posts.csv"'
    assert_includes transport.last.body, CSV
    assert_equal 1, result.valid_rows
    assert_equal Time.utc(2026, 11, 1, 10, 0, 0), result.rows[0].schedule_at
  end

  def test_commit_reads_the_batch
    transport.stub(:post, '/posts/bulk-import/commit', status: 201, json: {
                     'batch_id' => 'batch_1', 'created' => 1, 'held_for_approval' => false,
                     'posts' => [{ 'id' => 'post_1', 'schedule_at' => nil }]
                   })

    result = client.posts.commit_bulk_import(workspace_id: 'ws_1',
                                             file: { filename: 'posts.csv', data: CSV, mime_type: 'text/csv' })

    assert_equal '/v1/posts/bulk-import/commit', transport.last.path
    assert_equal 'batch_1', result.batch_id
    assert_equal 'post_1', result.posts[0].id
  end
end
