# frozen_string_literal: true

require 'test_helper'

class LabelsTest < Minitest::Test
  include ClientHelpers

  def test_create_get_update_and_delete
    transport
      .stub(:post, '/labels', status: 201, json: LABEL_FIXTURE)
      .stub(:get, '/labels/lbl_1', json: LABEL_FIXTURE)
      .stub(:put, '/labels/lbl_1', json: LABEL_FIXTURE.merge('name' => 'Relaunch'))
      .stub(:delete, '/labels/lbl_1', status: 204)

    label = client.labels.create(workspace_id: 'ws_1', name: 'Launch', color: '#4F46E5')

    assert_equal 'POST', transport.last.method
    assert_equal({ 'workspace_id' => 'ws_1', 'name' => 'Launch', 'color' => '#4F46E5' }, transport.last.json)
    assert_equal 'lbl_1', label.id

    assert_equal 'Launch', client.labels.get('lbl_1').name

    assert_equal 'Relaunch', client.labels.update('lbl_1', name: 'Relaunch', color: '#4F46E5').name
    assert_equal 'PUT', transport.last.method
    assert_equal({ 'name' => 'Relaunch', 'color' => '#4F46E5' }, transport.last.json)

    assert_nil client.labels.delete('lbl_1')
    assert_equal 'DELETE', transport.last.method
    assert_equal '/v1/labels/lbl_1', transport.last.path
  end
end
