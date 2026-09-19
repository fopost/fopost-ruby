# frozen_string_literal: true

require 'test_helper'

class MediaTest < Minitest::Test
  include ClientHelpers

  PRESIGN_FIXTURE = {
    'uploadId' => 'upl_1',
    'uploadUrl' => 'https://storage.test.fopost.com/staging/upl_1',
    'method' => 'PUT',
    'headers' => { 'Content-Type' => 'image/png' },
    'expiresAt' => '2026-09-19T12:00:00.000Z'
  }.freeze

  MEDIA_FIXTURE = {
    'id' => 'med_1',
    'type' => 'image',
    'name' => 'logo.png',
    'url' => 'media/ws_1/med_1.png',
    'previewUrl' => 'https://api.test.fopost.com/v1/media/med_1/file',
    'size' => 4
  }.freeze

  def test_presign_sends_the_declared_file_and_parses_the_slot
    transport.stub(:post, '/media/presign', status: 201, json: { 'data' => PRESIGN_FIXTURE })

    upload = client.media.presign(workspace_id: 'ws_1', filename: 'logo.png', mime_type: 'image/png', size: 4)

    assert_equal({ 'workspaceId' => 'ws_1', 'filename' => 'logo.png', 'mimeType' => 'image/png', 'size' => 4 },
                 transport.last.json)
    assert_equal 'upl_1', upload.upload_id
    assert_equal 'PUT', upload.method
    assert_equal({ 'Content-Type' => 'image/png' }, upload.headers)
    assert_equal Time.utc(2026, 9, 19, 12, 0, 0), upload.expires_at
  end

  def test_complete_returns_the_media_item
    transport.stub(:post, '/media/presign/upl_1/complete', status: 201, json: { 'data' => MEDIA_FIXTURE })

    item = client.media.complete('upl_1')

    assert_nil transport.last.body
    assert_equal 'med_1', item.id
    assert_equal 'image', item.type
    assert_equal 'https://api.test.fopost.com/v1/media/med_1/file', item.preview_url
  end

  def test_upload_direct_presigns_puts_the_bytes_and_completes
    transport
      .stub(:post, '/media/presign', status: 201, json: { 'data' => PRESIGN_FIXTURE })
      .stub(:put, '/staging/upl_1', status: 200, body: '')
      .stub(:post, '/media/presign/upl_1/complete', status: 201, json: { 'data' => MEDIA_FIXTURE })

    item = client.media.upload_direct(workspace_id: 'ws_1', filename: 'logo.png', mime_type: 'image/png',
                                      data: "\x89PNG".b)

    assert_equal 'med_1', item.id
    assert_equal 3, transport.calls.size

    presign, put, complete = transport.calls

    assert_equal 4, presign.json['size']

    assert_equal 'PUT', put.method
    assert_equal 'https://storage.test.fopost.com/staging/upl_1', put.uri.to_s
    assert_equal "\x89PNG".b, put.body
    assert_equal({ 'Content-Type' => 'image/png', 'Content-Length' => '4' }, put.headers)
    refute put.headers.key?('X-API-Key')

    assert_equal '/v1/media/presign/upl_1/complete', complete.path
    assert_equal API_KEY, complete.headers['X-API-Key']
  end

  def test_upload_direct_raises_on_a_rejected_put_and_never_completes
    transport
      .stub(:post, '/media/presign', status: 201, json: { 'data' => PRESIGN_FIXTURE })
      .stub(:put, '/staging/upl_1', status: 403, body: '<Error><Code>AccessDenied</Code></Error>')

    error = assert_raises(Fopost::PermissionDeniedError) do
      client.media.upload_direct(workspace_id: 'ws_1', filename: 'logo.png', mime_type: 'image/png', data: 'abcd')
    end

    assert_equal 403, error.status
    assert_equal %w[POST PUT], transport.calls.map(&:method)
  end
end
