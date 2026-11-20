# frozen_string_literal: true

require 'test_helper'

class DesignsTest < Minitest::Test
  include ClientHelpers

  DOCUMENT = { 'version' => 1, 'pages' => [{ 'id' => 'p1', 'layers' => [] }] }.freeze

  DESIGN = {
    'id' => 'des_1',
    'name' => 'Launch Story',
    'kind' => 'story',
    'width' => 1080,
    'height' => 1920,
    'document' => DOCUMENT,
    'thumbnail_media_id' => 'med_9',
    'thumbnail_url' => 'https://api.fopost.com/v1/media/med_9/file',
    'created_at' => '2026-11-20T10:00:00.000Z',
    'updated_at' => '2026-11-20T11:00:00.000Z'
  }.freeze

  def test_list_sends_the_filters_and_reads_designs
    transport.stub(:get, '/designs', json: { 'data' => [DESIGN.except('document')] })

    designs = client.designs.list(workspace_id: 'ws_1', kind: 'story', limit: 10, offset: 20)

    assert_equal 'GET', transport.last.method
    assert_equal '/v1/designs', transport.last.path
    assert_equal({ 'workspace_id' => 'ws_1', 'kind' => 'story', 'limit' => '10', 'offset' => '20' },
                 transport.last.query)
    assert_equal 'des_1', designs[0].id
    assert_equal 1080, designs[0].width
    assert_empty(designs[0].document)
  end

  def test_create_passes_the_document_through
    transport.stub(:post, '/designs', status: 201, json: { 'data' => DESIGN })

    design = client.designs.create(workspace_id: 'ws_1', kind: 'story', name: 'Launch Story', document: DOCUMENT,
                                   brand_voice_id: 'bv_1')

    assert_equal 'POST', transport.last.method
    assert_equal({ 'workspace_id' => 'ws_1', 'kind' => 'story', 'name' => 'Launch Story', 'document' => DOCUMENT,
                   'brand_voice_id' => 'bv_1' }, transport.last.json)
    assert_equal DOCUMENT, design.document
    assert_equal Time.utc(2026, 11, 20, 10, 0, 0), design.created_at
  end

  def test_get_reads_one_design
    transport.stub(:get, '/designs/des_1', json: { 'data' => DESIGN })

    design = client.designs.get('des_1')

    assert_equal '/v1/designs/des_1', transport.last.path
    assert_equal 'Launch Story', design.name
    assert_equal 'med_9', design.thumbnail_media_id
  end

  def test_update_sends_only_the_named_fields
    transport.stub(:patch, '/designs/des_1', json: { 'data' => DESIGN.merge('name' => 'Renamed') })

    design = client.designs.update('des_1', name: 'Renamed', create_version: true)

    assert_equal 'PATCH', transport.last.method
    assert_equal({ 'name' => 'Renamed', 'create_version' => true }, transport.last.json)
    assert_equal 'Renamed', design.name
  end

  def test_delete_answers_nil
    transport.stub(:delete, '/designs/des_1', json: { 'data' => { 'id' => 'des_1', 'deleted' => true } })

    assert_nil client.designs.delete('des_1')
    assert_equal 'DELETE', transport.last.method
  end

  def test_versions_asks_for_documents_when_told
    transport.stub(:get, '/designs/des_1/versions', json: {
                     'data' => [{ 'id' => 'ver_1', 'version' => 3, 'document' => DOCUMENT,
                                  'created_at' => '2026-11-20T09:00:00.000Z' }]
                   })

    versions = client.designs.versions('des_1', include_document: true)

    assert_equal({ 'include' => 'document' }, transport.last.query)
    assert_equal 3, versions[0].version
    assert_equal DOCUMENT, versions[0].document
  end

  def test_versions_sends_no_query_by_default
    transport.stub(:get, '/designs/des_1/versions', json: { 'data' => [] })

    assert_empty client.designs.versions('des_1')
    assert_empty transport.last.query
  end

  def test_restore_version_posts_to_the_version
    transport.stub(:post, '/designs/des_1/versions/ver_1/restore', json: { 'data' => DESIGN })

    design = client.designs.restore_version('des_1', 'ver_1')

    assert_equal 'POST', transport.last.method
    assert_equal '/v1/designs/des_1/versions/ver_1/restore', transport.last.path
    assert_equal 'des_1', design.id
  end

  def test_duplicate_sends_the_new_name
    transport.stub(:post, '/designs/des_1/duplicate', status: 201, json: { 'data' => DESIGN.merge('id' => 'des_2') })

    design = client.designs.duplicate('des_1', name: 'Copy')

    assert_equal({ 'name' => 'Copy' }, transport.last.json)
    assert_equal 'des_2', design.id
  end

  def test_export_reads_the_files
    transport.stub(:post, '/designs/des_1/export', json: {
                     'data' => { 'format' => 'mp4', 'files' => [
                       { 'media_id' => 'med_5', 'page_index' => 0, 'mime_type' => 'video/mp4',
                         'preview_url' => 'https://api.fopost.com/v1/media/med_5/file' }
                     ] }
                   })

    export = client.designs.export('des_1', format: 'mp4', page_indexes: [0], duration_sec: 10)

    assert_equal({ 'format' => 'mp4', 'page_indexes' => [0], 'duration_sec' => 10 }, transport.last.json)
    assert_equal 'mp4', export.format
    assert_equal 'med_5', export.files[0].media_id
    assert_equal 'video/mp4', export.files[0].mime_type
  end

  def test_bulk_sends_rows_and_reads_designs
    transport.stub(:post, '/designs/des_1/bulk', status: 201, json: {
                     'data' => [DESIGN.merge('id' => 'des_3'), DESIGN.merge('id' => 'des_4')]
                   })

    designs = client.designs.bulk('des_1', rows: [{ 'name' => 'Ana' }, { 'name' => 'Ben' }], name_column: 'name')

    assert_equal({ 'rows' => [{ 'name' => 'Ana' }, { 'name' => 'Ben' }], 'name_column' => 'name' },
                 transport.last.json)
    assert_equal %w[des_3 des_4], designs.map(&:id)
  end

  def test_posts_reads_the_posts_using_the_design
    transport.stub(:get, '/designs/des_1/posts', json: {
                     'data' => [{ 'id' => 'post_1', 'status' => 'published', 'text' => 'Hi',
                                  'published_at' => '2026-11-20T12:00:00.000Z', 'platforms' => ['instagram'],
                                  'engagement' => 12, 'views' => 300 }]
                   })

    posts = client.designs.posts('des_1')

    assert_equal 'GET', transport.last.method
    assert_equal 'published', posts[0].status
    assert_equal ['instagram'], posts[0].platforms
    assert_equal Time.utc(2026, 11, 20, 12, 0, 0), posts[0].published_at
  end

  def test_text_to_slides_reads_the_outline
    transport.stub(:post, '/designs/text-to-slides', json: {
                     'data' => {
                       'cover' => { 'title' => 'Five Tips', 'subtitle' => 'For launch week' },
                       'slides' => [{ 'heading' => 'Plan', 'body' => 'Start early.' }],
                       'cta' => { 'heading' => 'Follow', 'body' => 'For more.' },
                       'brand' => { 'colors' => ['#111111'], 'fonts' => {}, 'logo_media_id' => nil }
                     }
                   })

    outline = client.designs.text_to_slides(workspace_id: 'ws_1', text: 'Five tips', max_slides: 6)

    assert_equal({ 'workspace_id' => 'ws_1', 'text' => 'Five tips', 'max_slides' => 6 }, transport.last.json)
    assert_equal 'Five Tips', outline.cover['title']
    assert_equal 'Plan', outline.slides[0].heading
    assert_equal 'Follow', outline.cta.heading
    assert_equal ['#111111'], outline.brand['colors']
  end

  def test_from_post_sends_the_layout_options
    transport.stub(:post, '/designs/from-post', status: 201, json: { 'data' => DESIGN.merge('kind' => 'post') })

    design = client.designs.from_post(workspace_id: 'ws_1', post_id: 'post_1', style: 'quote', carousel: false)

    assert_equal({ 'workspace_id' => 'ws_1', 'post_id' => 'post_1', 'style' => 'quote', 'carousel' => false },
                 transport.last.json)
    assert_equal 'post', design.kind
  end
end
