# frozen_string_literal: true

require 'test_helper'
require 'stringio'

class UploadFilesTest < Minitest::Test
  include ClientHelpers

  LIMITS_FIXTURE = {
    'maxFileBytes' => 419_430_400,
    'source' => 'accounts',
    'connectedAccounts' => 5,
    'largeUploadsEnabled' => false,
    'nextTier' => { 'upToAccounts' => 15, 'maxFileBytes' => 2_147_483_648 },
    'multipartMaxFileBytes' => 104_857_600,
    'maxFilesPerUpload' => 5,
    'directUploadAvailable' => true,
    'allowedTypes' => ['image/png', 'video/mp4']
  }.freeze

  PRESIGN_FIXTURE = {
    'uploadId' => 'upl_1',
    'uploadUrl' => 'https://storage.test.fopost.com/staging/upl_1',
    'method' => 'PUT',
    'headers' => { 'Content-Type' => 'video/mp4' },
    'expiresAt' => '2026-09-19T12:00:00.000Z',
    'maxFileBytes' => 419_430_400
  }.freeze

  MEDIA_FIXTURE = {
    'id' => 'med_1', 'type' => 'video', 'name' => 'clip.mp4', 'url' => 'media/ws_1/med_1.mp4', 'size' => 7
  }.freeze

  def test_limits_reads_the_ceilings
    transport.stub(:get, '/media/limits', json: { 'data' => LIMITS_FIXTURE })

    limits = client.media.limits(workspace_id: 'ws_1')

    assert_equal({ 'workspaceId' => 'ws_1' }, transport.last.query)
    assert_equal 419_430_400, limits.max_file_bytes
    assert_equal 'accounts', limits.source
    assert_equal 5, limits.connected_accounts
    refute limits.large_uploads_enabled
    assert_equal 15, limits.next_tier.up_to_accounts
    assert_equal 2_147_483_648, limits.next_tier.max_file_bytes
    assert_equal 104_857_600, limits.multipart_max_file_bytes
    assert_equal 5, limits.max_files_per_upload
    assert limits.direct_upload_available
    assert_equal ['image/png', 'video/mp4'], limits.allowed_types
  end

  def test_presign_sends_the_optional_fields_and_reads_max_file_bytes
    transport.stub(:post, '/media/presign', status: 201, json: { 'data' => PRESIGN_FIXTURE })

    upload = client.media.presign(workspace_id: 'ws_1', filename: 'face.png', mime_type: 'image/png', size: 4,
                                  folder_id: 'fld_1', origin: 'chat', brand_role: 'person', brand_voice_id: 'bv_1',
                                  person_consent: { 'subject' => 'Jane', 'statement' => 'Agreed' })

    assert_equal({ 'workspaceId' => 'ws_1', 'filename' => 'face.png', 'mimeType' => 'image/png', 'size' => 4,
                   'folderId' => 'fld_1', 'origin' => 'chat', 'brandRole' => 'person', 'brandVoiceId' => 'bv_1',
                   'personConsent' => { 'subject' => 'Jane', 'statement' => 'Agreed' } }, transport.last.json)
    assert_equal 419_430_400, upload.max_file_bytes
  end

  def test_create_with_small_files_sends_one_multipart_request
    transport
      .stub(:get, '/media/limits', json: { 'data' => LIMITS_FIXTURE })
      .stub(:post, '/posts', status: 201, json: POST_FIXTURE)

    post = client.posts.create(workspace_id: 'ws_1', content: 'Hello', accounts: ['acc_1'],
                               files: [{ filename: 'a.png', data: "\x89PNG".b, mime_type: 'image/png' },
                                       StringIO.new('abc').tap { |io| io.define_singleton_method(:path) { 'b.gif' } }])

    assert_equal 'post_1', post.id
    assert_equal %w[GET POST], transport.calls.map(&:method)

    call = transport.last
    content_type = call.headers['Content-Type']
    boundary = content_type[/boundary=(.+)\z/, 1]

    assert_match %r{\Amultipart/form-data; boundary=}, content_type
    sections = call.body.split("--#{boundary}")

    assert_equal 5, sections.size
    assert_includes sections[1], 'name="post"'
    post_json = JSON.parse(sections[1].split("\r\n\r\n", 2).last.strip)

    assert_equal 'ws_1', post_json['workspace_id']
    assert_equal [{ 'text' => 'Hello' }], post_json['content']
    assert_includes sections[2], 'name="files"; filename="a.png"'
    assert_includes sections[2], 'Content-Type: image/png'
    assert_includes sections[2], "\x89PNG".b
    assert_includes sections[3], 'name="files"; filename="b.gif"'
    assert_includes sections[3], 'Content-Type: image/gif'
    assert_equal "--\r\n", sections[4]
  end

  def test_create_with_a_large_file_uploads_directly_and_attaches_the_item
    transport
      .stub(:get, '/media/limits', json: { 'data' => LIMITS_FIXTURE.merge('multipartMaxFileBytes' => 4) })
      .stub(:post, '/media/presign', status: 201, json: { 'data' => PRESIGN_FIXTURE })
      .stub(:put, '/staging/upl_1', status: 200, body: '')
      .stub(:post, '/media/presign/upl_1/complete', status: 201, json: { 'data' => MEDIA_FIXTURE })
      .stub(:post, '/posts', status: 201, json: POST_FIXTURE)

    client.posts.create(workspace_id: 'ws_1', content: %w[Hello Second], accounts: ['acc_1'],
                        files: [{ filename: 'clip.mp4', data: 'abcdefg', mime_type: 'video/mp4' }])

    assert_equal %w[GET POST PUT POST POST], transport.calls.map(&:method)
    assert_equal 'abcdefg', transport.calls[2].body

    create = transport.last

    assert_equal 'application/json', create.headers['Content-Type']
    assert_equal [{ 'text' => 'Hello',
                    'media' => [{ 'type' => 'video', 'name' => 'clip.mp4', 'url' => 'media/ws_1/med_1.mp4',
                                  'size' => 7 }] },
                  { 'text' => 'Second' }], create.json['content']
  end

  def test_create_falls_back_to_the_default_ceiling_when_limits_fail
    transport
      .stub(:get, '/media/limits', status: 500, json: { 'error' => 'server_error', 'message' => 'down' })
      .stub(:post, '/posts', status: 201, json: POST_FIXTURE)

    client.posts.create(workspace_id: 'ws_1', content: 'Hello',
                        files: [{ filename: 'a.png', data: 'abcd', mime_type: 'image/png' }])

    assert_match %r{\Amultipart/form-data}, transport.last.headers['Content-Type']
  end

  def test_update_without_content_appends_to_the_first_block_on_the_direct_path
    transport
      .stub(:get, '/media/limits', json: { 'data' => LIMITS_FIXTURE.merge('multipartMaxFileBytes' => 4) })
      .stub(:get, '/posts/post_1', json: POST_FIXTURE)
      .stub(:post, '/media/presign', status: 201, json: { 'data' => PRESIGN_FIXTURE })
      .stub(:put, '/staging/upl_1', status: 200, body: '')
      .stub(:post, '/media/presign/upl_1/complete', status: 201, json: { 'data' => MEDIA_FIXTURE })
      .stub(:put, '/posts/post_1', json: POST_FIXTURE)

    client.posts.update('post_1', title: 'Renamed',
                                  files: [{ filename: 'clip.mp4', data: 'abcdefg', mime_type: 'video/mp4' }])

    assert_equal 'ws_1', transport.calls[2].json['workspaceId']
    update = transport.last

    assert_equal 'Renamed', update.json['title']
    assert_equal 'Hello from Ruby', update.json['content'][0]['text']
    assert_equal 'media/ws_1/med_1.mp4', update.json['content'][0]['media'][0]['url']
  end

  def test_update_with_small_files_puts_multipart
    transport
      .stub(:get, '/media/limits', json: { 'data' => LIMITS_FIXTURE })
      .stub(:put, '/posts/post_1', json: POST_FIXTURE)

    client.posts.update('post_1', files: [{ filename: 'a.png', data: 'abcd', mime_type: 'image/png' }])

    assert_equal 'PUT', transport.last.method
    assert_includes transport.last.body, 'name="post"'
    assert_includes transport.last.body, "\r\n\r\n{}\r\n"
  end

  def test_file_too_large_is_a_413_with_the_ceiling_readable
    transport.stub(:post, '/media/upload', status: 413, json: {
                     'error' => 'file_too_large', 'message' => 'Too big', 'max_file_bytes' => 104_857_600,
                     'file_bytes' => 200_000_000, 'upgrade_url' => 'https://app.test.fopost.com/settings/billing'
                   })

    error = assert_raises(Fopost::FileTooLargeError) { client.request(:post, '/media/upload', json: {}) }

    assert_kind_of Fopost::Error, error
    assert_equal 413, error.status
    assert_equal 'file_too_large', error.code
    assert_equal 104_857_600, error.max_file_bytes
    assert_equal 200_000_000, error.file_bytes
    assert_equal 'https://app.test.fopost.com/settings/billing', error.upgrade_url
    assert_equal 104_857_600, error.body['max_file_bytes']
  end
end
