# frozen_string_literal: true

require 'test_helper'

class WhatsappTest < Minitest::Test
  include ClientHelpers

  def test_whatsapp_is_on_the_platform_list
    assert_includes Fopost::PLATFORMS, 'whatsapp'
  end

  def test_a_template_create_returns_the_review_status_the_platform_gave_it
    transport.stub(:post, '/accounts/a1/whatsapp/templates', json: {
                     'data' => {
                       'id' => 'tpl-1',
                       'name' => 'order_shipped',
                       'language' => 'en_US',
                       'category' => 'UTILITY',
                       'status' => 'PENDING',
                       'rejectedReason' => nil,
                       'components' => [],
                       'qualityScore' => nil
                     }
                   })

    template = client.whatsapp.create_template(
      'a1',
      name: 'order_shipped',
      language: 'en_US',
      category: 'UTILITY',
      components: [{ type: 'BODY', text: 'On its way.' }]
    )

    assert_equal '/v1/accounts/a1/whatsapp/templates', transport.last.path
    # Nothing marks a template approved but the platform.
    assert_equal 'PENDING', template.status
    assert_equal 'order_shipped', template.name
  end

  def test_a_sandbox_session_carries_only_the_last_four_digits
    transport.stub(:post, '/whatsapp/sandbox/sessions', json: {
                     'data' => {
                       'id' => 'ses-1',
                       'status' => 'invited',
                       'phoneNumberLast4' => '4567',
                       'invitedAt' => '2026-09-20T10:00:00Z',
                       'activatedAt' => nil,
                       'expiresAt' => '2026-09-21T10:00:00Z'
                     }
                   })

    session = client.whatsapp.create_sandbox_session(workspace_id: 'ws', phone_number: '+15551234567')

    assert_equal '/v1/whatsapp/sandbox/sessions', transport.last.path
    assert_equal '4567', session.phone_number_last4
    assert_equal 'invited', session.status
  end
end
