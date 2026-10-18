# frozen_string_literal: true

require 'test_helper'

class MediaLibraryTest < Minitest::Test
  include ClientHelpers

  ITEM = {
    'id' => 'med_1', 'workspace_id' => 'ws_1', 'name' => 'logo.png', 'url' => 'https://cdn.yourbrand.com/logo.png',
    'type' => 'image', 'mime_type' => 'image/png', 'size' => 4096, 'tags' => ['brand'], 'brand_role' => 'logo',
    'has_person_consent' => false, 'created_at' => '2026-10-01T10:00:00.000Z',
    'preview_url' => 'https://api.fopost.com/v1/media/med_1/file',
    'share' => { 'url' => 'https://fopost.com/s/abc', 'created_at' => '2026-10-02T10:00:00.000Z',
                 'created_by_name' => nil, 'source' => 'manual' }
  }.freeze

  def test_list_pages_the_library
    transport.stub(:get, '/media', json: {
                     'data' => [ITEM], 'meta' => { 'page' => 1, 'per_page' => 20, 'total' => 1, 'total_pages' => 1 }
                   })

    page = client.media.list(workspace_id: 'ws_1', type: 'image', brand_role: 'logo', shared: true, page: 1)

    assert_equal({ 'workspace_id' => 'ws_1', 'type' => 'image', 'brand_role' => 'logo', 'shared' => 'true',
                   'page' => '1' }, transport.last.query)
    assert_equal 'logo', page[0].brand_role
    assert_equal 'https://fopost.com/s/abc', page[0].share.url
    assert_equal 1, page.meta.total_pages
  end

  def test_upload_sends_files_as_multipart
    transport.stub(:post, '/media/upload', status: 201, json: {
                     'data' => [{ 'id' => 'med_1', 'type' => 'image', 'name' => 'logo.png',
                                  'url' => 'https://cdn.yourbrand.com/logo.png', 'size' => 4 }]
                   })

    items = client.media.upload([{ filename: 'logo.png', data: 'PNG!', mime_type: 'image/png' }], workspace_id: 'ws_1')

    assert_equal 'POST', transport.last.method
    assert_match %r{\Amultipart/form-data; boundary=}, transport.last.headers['Content-Type']
    assert_includes transport.last.body, 'name="workspaceId"'
    assert_includes transport.last.body, 'name="files"; filename="logo.png"'
    assert_includes transport.last.body, 'Content-Type: image/png'
    assert_equal 'med_1', items[0].id
  end

  def test_delete_removes_the_item
    transport.stub(:delete, '/media/med_1', status: 204)

    assert_nil client.media.delete('med_1')
    assert_equal 'DELETE', transport.last.method
    assert_equal '/v1/media/med_1', transport.last.path
  end
end
