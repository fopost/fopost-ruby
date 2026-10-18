# frozen_string_literal: true

require 'test_helper'

class WorkspacesTest < Minitest::Test
  include ClientHelpers

  def test_create_update_and_delete
    transport
      .stub(:post, '/workspaces', status: 201, json: WORKSPACE_FIXTURE.merge('connect_redirect_domains' => []))
      .stub(:put, '/workspaces/ws_1', json: WORKSPACE_FIXTURE.merge('require_approval' => true))
      .stub(:delete, '/workspaces/ws_1', status: 204)

    workspace = client.workspaces.create(name: 'Acme', type: 'BRAND', timezone: 'UTC')

    assert_equal 'POST', transport.last.method
    assert_equal({ 'name' => 'Acme', 'type' => 'BRAND', 'timezone' => 'UTC' }, transport.last.json)
    assert_equal 'acme', workspace.slug
    assert_equal [], workspace.connect_redirect_domains

    updated = client.workspaces.update('ws_1', require_approval: true, brand_color: nil,
                                               connect_redirect_domains: ['yourbrand.com'])

    assert_equal 'PUT', transport.last.method
    assert_equal({ 'requireApproval' => true, 'brandColor' => nil, 'connectRedirectDomains' => ['yourbrand.com'] },
                 transport.last.json)
    assert updated.require_approval

    assert_nil client.workspaces.delete('ws_1')
    assert_equal 'DELETE', transport.last.method
    assert_equal '/v1/workspaces/ws_1', transport.last.path
  end
end
