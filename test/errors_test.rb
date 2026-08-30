# frozen_string_literal: true

require 'test_helper'

class ErrorsTest < Minitest::Test
  include ClientHelpers

  STATUSES = {
    400 => Fopost::ValidationError,
    401 => Fopost::AuthenticationError,
    402 => Fopost::PaymentRequiredError,
    403 => Fopost::PermissionDeniedError,
    404 => Fopost::NotFoundError,
    422 => Fopost::ValidationError,
    429 => Fopost::RateLimitError,
    500 => Fopost::Error
  }.freeze

  def test_each_status_maps_to_its_error_class
    STATUSES.each do |status, klass|
      transport = StubTransport.new
      transport.stub(:get, '/workspaces', status: status, json: { 'error' => 'nope', 'message' => 'Nope.' })
      c = Fopost::Client.new(api_key: API_KEY, base_url: BASE_URL, transport: transport,
                             max_retries: 1, sleeper: ->(_) {})

      error = assert_raises(klass) { c.workspaces.list }
      assert_equal status, error.status
      assert_equal 'nope', error.code
      assert_equal 'Nope.', error.message
    end
  end

  def test_message_falls_back_to_the_code_then_the_status
    transport.stub(:get, '/workspaces', status: 403, json: { 'error' => 'forbidden' })

    assert_equal 'forbidden', assert_raises(Fopost::PermissionDeniedError) { client.workspaces.list }.message
  end

  def test_a_non_json_body_becomes_the_message
    transport.stub(:get, '/workspaces', status: 502, body: 'Bad Gateway', headers: { 'content-type' => 'text/plain' })

    error = assert_raises(Fopost::Error) { client.workspaces.list }
    assert_equal 'Bad Gateway', error.message
    assert_equal 502, error.status
  end

  def test_to_s_carries_the_status_and_code
    error = Fopost::ErrorFactory.build(404, { 'error' => 'not_found', 'message' => 'No such post.' })

    assert_equal '[404 (not_found)] No such post.', error.to_s
  end

  def test_validation_errors_expose_per_field_messages
    transport.stub(:post, '/posts', status: 422, json: {
                     'error' => 'validation_failed',
                     'message' => 'Invalid body.',
                     'errors' => { 'content' => ['is required'] }
                   })

    error = assert_raises(Fopost::ValidationError) do
      client.posts.create(workspace_id: 'ws_1', content: '', accounts: [])
    end

    assert_equal({ 'content' => ['is required'] }, error.errors)
  end

  def test_a_json_success_body_that_is_not_json_raises
    transport.stub(:get, '/workspaces', status: 200, body: '<html>', headers: { 'content-type' => 'text/html' })

    error = assert_raises(Fopost::Error) { client.workspaces.list }
    assert_match(/Expected a JSON response/, error.message)
  end

  def test_every_error_is_rescuable_as_fopost_error
    STATUSES.each_value { |klass| assert_operator klass, :<=, Fopost::Error }
  end
end
