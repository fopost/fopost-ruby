# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

class FontsTest < Minitest::Test
  include ClientHelpers

  FONT = {
    'id' => 'font_1',
    'family' => 'Brand Sans',
    'style' => 'normal',
    'weight' => 700,
    'format' => 'woff2',
    'file_url' => 'https://api.fopost.com/v1/fonts/font_1/file',
    'created_at' => '2026-11-20T10:00:00.000Z'
  }.freeze

  def test_list_reads_the_library_and_uploads
    transport.stub(:get, '/fonts', json: {
                     'library' => [{ 'slug' => 'geist', 'family' => 'Geist', 'category' => 'sans-serif',
                                     'scripts' => ['latin'], 'weights' => [400, 700],
                                     'files' => [{ 'path' => 'geist/latin.woff2', 'subset' => 'latin',
                                                   'weight' => 400, 'style' => 'normal',
                                                   'unicode_range' => 'U+0000-00FF' }] }],
                     'uploaded' => [FONT]
                   })

    fonts = client.fonts.list(workspace_id: 'ws_1')

    assert_equal 'GET', transport.last.method
    assert_equal({ 'workspace_id' => 'ws_1' }, transport.last.query)
    assert_equal 'Geist', fonts.library[0].family
    assert_equal 'U+0000-00FF', fonts.library[0].files[0].unicode_range
    assert_equal 'font_1', fonts.uploaded[0].id
    assert_equal 700, fonts.uploaded[0].weight
  end

  def test_upload_sends_one_file_as_multipart
    transport.stub(:post, '/fonts', status: 201, json: FONT)

    font = client.fonts.upload({ filename: 'brand.woff2', data: 'wOF2' }, workspace_id: 'ws_1', family: 'Brand Sans',
                                                                          weight: 700, style: 'normal')

    assert_equal 'POST', transport.last.method
    assert_equal '/v1/fonts', transport.last.path
    assert_match %r{\Amultipart/form-data; boundary=}, transport.last.headers['Content-Type']
    body = transport.last.body

    assert_includes body, 'name="workspace_id"'
    assert_includes body, 'name="family"'
    assert_includes body, "name=\"weight\"\r\n\r\n700"
    assert_includes body, 'name="file"; filename="brand.woff2"'
    assert_includes body, 'Content-Type: font/woff2'
    assert_equal 'Brand Sans', font.family
    assert_equal Time.utc(2026, 11, 20, 10, 0, 0), font.created_at
  end

  def test_upload_reads_a_path
    path = File.join(Dir.mktmpdir, 'brand.ttf')
    File.binwrite(path, 'TTF!')
    transport.stub(:post, '/fonts', status: 201, json: FONT)

    client.fonts.upload(path, workspace_id: 'ws_1')

    assert_includes transport.last.body, 'filename="brand.ttf"'
    assert_includes transport.last.body, 'Content-Type: font/ttf'
    refute_includes transport.last.body, 'name="family"'
  end

  def test_delete_answers_nil
    transport.stub(:delete, '/fonts/font_1', status: 204)

    assert_nil client.fonts.delete('font_1')
    assert_equal 'DELETE', transport.last.method
    assert_equal '/v1/fonts/font_1', transport.last.path
  end
end
