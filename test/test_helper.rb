# frozen_string_literal: true

$LOAD_PATH.unshift File.expand_path('../lib', __dir__)

require 'json'
require 'minitest/autorun'
require 'fopost'

BASE_URL = 'https://api.test.fopost.com/api/v1'
BASE_PATH = '/api/v1'
API_KEY = 'fp_test_key'

# A transport that answers from a script instead of the network, and records
# every request so a test can assert on what went out.
class StubTransport
  include Fopost::HTTP::Transport

  Call = Struct.new(:method, :uri, :headers, :body, keyword_init: true) do
    def json
      body.nil? ? nil : JSON.parse(body)
    end

    def query
      URI.decode_www_form(uri.query.to_s).to_h
    end

    def path
      uri.path
    end
  end

  attr_reader :calls

  def initialize
    @routes = Hash.new { |hash, key| hash[key] = [] }
    @calls = []
  end

  # Queue a response. Stub the same route twice to answer twice; the last
  # queued response repeats once the queue runs dry.
  def stub(method, path, status: 200, json: nil, body: nil, headers: {})
    payload = json.nil? ? body.to_s : JSON.generate(json)
    headers = { 'content-type' => 'application/json' }.merge(headers) unless json.nil?
    @routes[key(method, path)] << { status: status, body: payload, headers: headers }
    self
  end

  def call(method:, url:, headers:, body:)
    @calls << Call.new(method: method, uri: url, headers: headers, body: body)

    queued = @routes[key(method, url.path)]
    raise "StubTransport: no stub for #{method} #{url.path}" if queued.empty?

    response = queued.size > 1 ? queued.shift : queued.first
    Fopost::HTTP::Response.new(**response)
  end

  def last
    calls.last
  end

  private

  def key(method, path)
    [method.to_s.upcase, path.start_with?('/api/') ? path : "#{BASE_PATH}#{path}"]
  end
end

module ClientHelpers
  def transport
    @transport ||= StubTransport.new
  end

  def slept
    @slept ||= []
  end

  def client(**options)
    @client ||= Fopost::Client.new(
      api_key: API_KEY,
      base_url: BASE_URL,
      transport: transport,
      sleeper: ->(seconds) { slept << seconds },
      **options
    )
  end
end

POST_FIXTURE = {
  'id' => 'post_1',
  'workspace_id' => 'ws_1',
  'status' => 'draft',
  'content_type' => 'post',
  'schedule_at' => nil,
  'repeatable' => false,
  'title' => nil,
  'summary' => nil,
  'content' => [{ 'id' => 1, 'text' => 'Hello from Ruby', 'media' => [], 'position' => 0 }],
  'accounts' => [
    {
      'id' => 'acc_1',
      'platform' => 'twitter',
      'username' => 'fopost',
      'name' => 'FoPost',
      'publish_status' => 'pending',
      'attempts' => 0,
      'max_attempts' => 3
    }
  ],
  'labels' => [],
  'settings' => {},
  'created_at' => '2026-08-12T10:00:00.000Z',
  'updated_at' => '2026-08-12T10:00:00.000Z'
}.freeze

ACCOUNT_FIXTURE = {
  'id' => 'acc_1',
  'workspaceId' => 'ws_1',
  'platform' => 'twitter',
  'username' => 'fopost',
  'name' => 'FoPost',
  'avatar' => nil,
  'isPrimary' => true,
  'active' => true,
  'healthStatus' => 'healthy',
  'lastHealthCheck' => '2026-08-12T09:00:00.000Z'
}.freeze

WORKSPACE_FIXTURE = {
  'id' => 'ws_1',
  'name' => 'Acme',
  'slug' => 'acme',
  'type' => 'brand',
  'timezone' => 'UTC',
  'language' => 'en',
  'require_approval' => false,
  'ai_alt_text_enabled' => true,
  'brand_color' => '#4F46E5',
  'role' => 'owner',
  'created_at' => '2026-01-01T00:00:00.000Z',
  'accounts' => [ACCOUNT_FIXTURE]
}.freeze

LABEL_FIXTURE = {
  'id' => 'lbl_1',
  'name' => 'Launch',
  'color' => '#4F46E5',
  'workspace' => { 'id' => 'ws_1', 'name' => 'Acme', 'slug' => 'acme' }
}.freeze
