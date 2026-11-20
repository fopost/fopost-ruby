# frozen_string_literal: true

require 'test_helper'

class VideoEditsTest < Minitest::Test
  include ClientHelpers

  EDIT = {
    'id' => 've_1',
    'status' => 'succeeded',
    'progress' => 1,
    'source_media_id' => 'med_1',
    'operations' => [{ 'op' => 'trim', 'params' => { 'start' => 2, 'end' => 12 } }],
    'result_media_id' => 'med_2',
    'result_media' => { 'id' => 'med_2', 'preview_url' => 'https://api.fopost.com/v1/media/med_2/file',
                        'mime_type' => 'video/mp4' },
    'extra_outputs' => [{ 'media_id' => 'med_3', 'label' => 'Subtitles', 'mime' => 'text/vtt',
                          'preview_url' => nil }],
    'result' => nil,
    'error' => nil,
    'created_at' => '2026-11-20T10:00:00.000Z',
    'updated_at' => '2026-11-20T10:01:00.000Z',
    'completed_at' => '2026-11-20T10:01:00.000Z'
  }.freeze

  def test_ops_lists_operations
    transport.stub(:get, '/video-edits/ops', json: {
                     'data' => [{ 'name' => 'subtitles', 'available' => true, 'uses_ai' => true }]
                   })

    ops = client.video_edits.ops

    assert_equal '/v1/video-edits/ops', transport.last.path
    assert_equal 'subtitles', ops[0].name
    assert ops[0].uses_ai
  end

  def test_list_sends_the_filters
    transport.stub(:get, '/video-edits', json: { 'data' => [EDIT] })

    edits = client.video_edits.list(workspace_id: 'ws_1', media_id: 'med_1', limit: 5)

    assert_equal({ 'workspace_id' => 'ws_1', 'media_id' => 'med_1', 'limit' => '5' }, transport.last.query)
    assert_equal 've_1', edits[0].id
    assert_equal 'trim', edits[0].operations[0].op
  end

  def test_create_sends_the_operations
    transport.stub(:post, '/video-edits', status: 201, json: EDIT.merge('status' => 'queued', 'progress' => 0))

    edit = client.video_edits.create(
      workspace_id: 'ws_1',
      media_id: 'med_1',
      operations: [{ op: :trim, params: { start: 2, end: 12 } }, { 'op' => 'denoise' }]
    )

    assert_equal 'POST', transport.last.method
    assert_equal({
                   'media_id' => 'med_1',
                   'operations' => [{ 'op' => 'trim', 'params' => { 'start' => 2, 'end' => 12 } },
                                    { 'op' => 'denoise' }],
                   'workspace_id' => 'ws_1'
                 }, transport.last.json)
    assert_equal 'queued', edit.status
  end

  def test_get_reads_the_result
    transport.stub(:get, '/video-edits/ve_1', json: EDIT)

    edit = client.video_edits.get('ve_1', workspace_id: 'ws_1')

    assert_equal({ 'workspace_id' => 'ws_1' }, transport.last.query)
    assert_equal 'med_2', edit.result_media.id
    assert_equal 'Subtitles', edit.extra_outputs[0].label
    assert_equal({ 'start' => 2, 'end' => 12 }, edit.operations[0].params)
    assert_equal Time.utc(2026, 11, 20, 10, 1, 0), edit.completed_at
  end
end
