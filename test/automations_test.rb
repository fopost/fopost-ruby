# frozen_string_literal: true

require 'test_helper'

class AutomationsTest < Minitest::Test
  include ClientHelpers

  GRAPH = {
    'nodes' => [
      { 'id' => 'n1', 'kind' => 'trigger', 'label' => nil, 'config' => {}, 'position' => 0,
        'layout' => { 'x' => 0, 'y' => 0 } },
      { 'id' => 'n2', 'kind' => 'publish', 'label' => 'Post it', 'config' => { 'accountIds' => ['acc_1'] },
        'position' => 1, 'layout' => nil }
    ],
    'edges' => [{ 'id' => 'e1', 'source' => 'n1', 'source_handle' => nil, 'target' => 'n2' }]
  }.freeze

  AUTOMATION = {
    'id' => 'auto_1',
    'workspace_id' => 'ws_1',
    'name' => 'RSS to X',
    'description' => nil,
    'trigger_type' => 'rss_feed',
    'trigger_config' => { 'url' => 'https://yourbrand.com/feed.xml' },
    'active' => true,
    'schedule_window' => { 'days' => [1, 2], 'start' => '09:00', 'end' => '17:00' },
    'max_per_day' => nil,
    'credit_ceiling' => 50,
    'approval_mode' => false,
    'last_triggered_at' => nil,
    'run_count' => 3,
    'graph' => GRAPH,
    'steps' => [{ 'position' => 1, 'node_id' => 'n2', 'action_type' => 'publish',
                  'action_config' => { 'accountIds' => ['acc_1'] } }],
    'created_at' => '2026-10-01T10:00:00.000Z',
    'updated_at' => '2026-10-01T10:00:00.000Z'
  }.freeze

  def test_list_get_stats_and_delete
    transport
      .stub(:get, '/automations', json: { 'data' => [AUTOMATION] })
      .stub(:get, '/automations/auto_1', json: AUTOMATION)
      .stub(:get, '/automations/stats', json: {
              'total_automations' => 2, 'active_automations' => 1, 'total_runs_24h' => 5,
              'runs_by_status' => { 'completed' => 4, 'failed' => 1 },
              'recent_runs' => [{ 'id' => 9, 'automation_id' => 'auto_1', 'status' => 'completed',
                                  'started_at' => '2026-10-01T10:00:00.000Z', 'completed_at' => nil }]
            })
      .stub(:delete, '/automations/auto_1', status: 204)

    automations = client.automations.list

    assert_equal 'rss_feed', automations[0].trigger_type
    assert_equal [1, 2], automations[0].schedule_window.days

    automation = client.automations.get('auto_1')

    assert_equal 'publish', automation.graph.nodes[1].kind
    assert_equal 'n2', automation.graph.edges[0].target
    assert_equal({ 'accountIds' => ['acc_1'] }, automation.steps[0].action_config)

    stats = client.automations.stats

    assert_equal 5, stats.total_runs_24h
    assert_equal 'completed', stats.recent_runs[0].status

    assert_nil client.automations.delete('auto_1')
    assert_equal 'DELETE', transport.last.method
  end

  def test_create_and_update_send_camel_case_bodies
    transport
      .stub(:post, '/automations', status: 201, json: AUTOMATION.merge('secret' => 'auto_secret'))
      .stub(:put, '/automations/auto_1', json: AUTOMATION.merge('active' => false))

    created = client.automations.create(
      workspace_id: 'ws_1', name: 'RSS to X', trigger_type: 'rss_feed',
      trigger_config: { 'url' => 'https://yourbrand.com/feed.xml' },
      steps: [{ action_type: 'publish', action_config: { account_ids: ['acc_1'] } }],
      graph: { nodes: [{ id: 'n1', kind: 'trigger', layout: { x: 0, y: 0 } }],
               edges: [{ id: 'e1', source: 'n1', source_handle: nil, target: 'n2' }] },
      active: true
    )

    assert_equal 'POST', transport.last.method
    assert_equal({
                   'workspaceId' => 'ws_1', 'name' => 'RSS to X', 'triggerType' => 'rss_feed',
                   'triggerConfig' => { 'url' => 'https://yourbrand.com/feed.xml' },
                   'steps' => [{ 'actionType' => 'publish', 'actionConfig' => { 'accountIds' => ['acc_1'] } }],
                   'graph' => { 'nodes' => [{ 'id' => 'n1', 'kind' => 'trigger', 'layout' => { 'x' => 0, 'y' => 0 } }],
                                'edges' => [{ 'id' => 'e1', 'source' => 'n1', 'sourceHandle' => nil,
                                              'target' => 'n2' }] },
                   'active' => true
                 }, transport.last.json)
    assert_equal 'auto_secret', created.secret

    updated = client.automations.update('auto_1', active: false, description: nil)

    assert_equal({ 'active' => false, 'description' => nil }, transport.last.json)
    refute updated.active
  end

  def test_versions_get_version_and_restore
    transport
      .stub(:get, '/automations/auto_1/versions', json: {
              'data' => [{ 'version' => 2, 'note' => 'Added publish', 'created_by' => { 'name' => 'Ops' },
                           'created_at' => '2026-10-02T10:00:00.000Z', 'node_count' => 2,
                           'nodes_added' => ['n2'], 'nodes_removed' => [] }],
              'meta' => { 'page' => 1, 'per_page' => 20, 'total' => 2, 'total_pages' => 1 }
            })
      .stub(:get, '/automations/auto_1/versions/2', json: {
              'version' => 2, 'note' => 'Added publish', 'created_by' => nil,
              'created_at' => '2026-10-02T10:00:00.000Z', 'graph' => GRAPH
            })
      .stub(:post, '/automations/auto_1/versions/2/restore', status: 201, json: {
              'version' => 3, 'graph' => GRAPH, 'steps' => []
            })

    versions = client.automations.versions('auto_1', page: 1, per_page: 20)

    assert_equal({ 'page' => '1', 'per_page' => '20' }, transport.last.query)
    assert_equal 2, versions[0].version
    assert_equal 'Ops', versions[0].created_by.name
    assert_equal ['n2'], versions[0].nodes_added
    assert_equal 1, versions.meta.total_pages

    version = client.automations.get_version('auto_1', 2)

    assert_equal 'GET', transport.last.method
    assert_equal 2, version.graph.nodes.size
    assert_nil version.created_by

    restored = client.automations.restore_version('auto_1', 2)

    assert_equal 'POST', transport.last.method
    assert_equal '/v1/automations/auto_1/versions/2/restore', transport.last.path
    assert_equal 3, restored.version
    assert_equal 'trigger', restored.graph.nodes[0].kind
  end

  def test_runs_and_get_run
    run = { 'id' => 9, 'automation_id' => 'auto_1', 'status' => 'failed', 'current_step' => 1,
            'started_at' => '2026-10-01T10:00:00.000Z', 'completed_at' => '2026-10-01T10:00:05.000Z',
            'error_message' => 'network down', 'defer_count' => 0, 'replay_of_run_id' => nil }
    transport
      .stub(:get, '/automations/auto_1/runs', json: {
              'data' => [run], 'meta' => { 'page' => 1, 'per_page' => 20, 'total' => 1, 'total_pages' => 1 }
            })
      .stub(:get, '/automations/auto_1/runs/9', json: run.merge(
        'logs' => [{ 'id' => 1, 'step_position' => 1, 'node_id' => 'n2', 'handle' => nil, 'status' => 'failed',
                     'input_snapshot' => { 'text' => 'Hi' }, 'output_snapshot' => nil,
                     'started_at' => '2026-10-01T10:00:00.000Z', 'completed_at' => nil,
                     'duration_ms' => 50, 'error_message' => 'network down' }]
      ))

    runs = client.automations.runs('auto_1')

    assert_equal 9, runs[0].id
    assert_equal 'network down', runs[0].error_message
    assert_equal 1, runs.meta.total

    detail = client.automations.get_run('auto_1', 9)

    assert_equal '/v1/automations/auto_1/runs/9', transport.last.path
    assert_equal 'n2', detail.logs[0].node_id
    assert_equal({ 'text' => 'Hi' }, detail.logs[0].input_snapshot)
  end
end
