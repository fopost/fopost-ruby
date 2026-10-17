# frozen_string_literal: true

require 'test_helper'

class KnowledgeTest < Minitest::Test
  include ClientHelpers

  SOURCE_FIXTURE = {
    'id' => 'know_1',
    'kind' => 'url',
    'title' => 'Refund policy',
    'status' => 'ready',
    'statusMessage' => nil,
    'url' => 'https://yourbrand.com/help/refunds',
    'mediaId' => nil,
    'brandVoiceId' => nil,
    'chunkCount' => 3,
    'content' => nil,
    'lastSyncedAt' => '2026-09-20T00:00:00.000Z',
    'createdAt' => '2026-09-19T00:00:00.000Z',
    'updatedAt' => '2026-09-20T00:00:00.000Z'
  }.freeze

  def test_list_parses_camel_case_fields_and_sends_the_workspace_filter
    transport.stub(:get, '/knowledge/sources', json: { 'data' => [SOURCE_FIXTURE] })

    sources = client.knowledge.list(workspace_id: 'ws_1')

    assert_equal 'GET', transport.last.method
    assert_equal '/v1/knowledge/sources', transport.last.path
    assert_equal({ 'workspace_id' => 'ws_1' }, transport.last.query)

    assert_equal 1, sources.length
    assert_equal 'know_1', sources[0].id
    assert_equal 'ready', sources[0].status
    assert_equal 3, sources[0].chunk_count
    assert_instance_of Time, sources[0].last_synced_at
  end

  def test_create_sends_a_snake_case_body
    transport.stub(:post, '/knowledge/sources', json: { 'data' => SOURCE_FIXTURE })

    client.knowledge.create(kind: 'file', title: 'Price list', media_id: 'media_1',
                            brand_voice_id: 'brand_1', workspace_id: 'ws_1')

    assert_equal 'POST', transport.last.method
    body = transport.last.json

    assert_equal 'file', body['kind']
    assert_equal 'media_1', body['media_id']
    assert_equal 'brand_1', body['brand_voice_id']
    assert_equal 'ws_1', body['workspace_id']
    # Nothing the caller left out reaches the wire.
    refute body.key?('url')
    refute body.key?('content')
  end

  def test_search_passes_top_k_and_parses_matches
    transport.stub(:get, '/knowledge/search', json: { 'data' => [{
                     'sourceId' => 'know_1',
                     'sourceTitle' => 'Refund policy',
                     'sourceKind' => 'url',
                     'sourceUrl' => 'https://yourbrand.com/help/refunds',
                     'text' => 'We refund within 30 days.',
                     'score' => 0.82
                   }] })

    matches = client.knowledge.search('how long do refunds take?', top_k: 3)

    assert_equal '/v1/knowledge/search', transport.last.path
    assert_equal({ 'q' => 'how long do refunds take?', 'top_k' => '3' }, transport.last.query)
    assert_equal 1, matches.length
    assert_equal 'Refund policy', matches[0].source_title
    assert_in_delta 0.82, matches[0].score, 0.0001
  end

  def test_sync_posts_to_the_sources_sync_path
    transport.stub(:post, '/knowledge/sources/know_1/sync',
                   json: { 'data' => { 'id' => 'know_1', 'status' => 'pending' } })

    assert_nil client.knowledge.sync('know_1')
    assert_equal 'POST', transport.last.method
    assert_equal '/v1/knowledge/sources/know_1/sync', transport.last.path
  end
end
