# frozen_string_literal: true

require 'test_helper'

# Meta messaging settings, the webhook subscription, and Messenger hand-over.
class MetaMessagingTest < Minitest::Test
  include ClientHelpers

  def test_ice_breakers_round_trip
    breakers = [{ 'question' => 'What are your hours?', 'payload' => 'HOURS' }]
    transport.stub(:get, '/accounts/acc_1/messaging/ice-breakers', json: { 'data' => { 'ice_breakers' => breakers } })
    transport.stub(:put, '/accounts/acc_1/messaging/ice-breakers', json: { 'data' => { 'ice_breakers' => breakers } })
    transport.stub(:delete, '/accounts/acc_1/messaging/ice-breakers', json: { 'data' => { 'ice_breakers' => [] } })

    assert_equal 'HOURS', client.accounts.get_ice_breakers('acc_1').ice_breakers[0].payload

    saved = client.accounts.set_ice_breakers('acc_1', [{ question: 'What are your hours?', payload: 'HOURS' }])

    assert_equal 'What are your hours?', saved.ice_breakers[0].question
    assert_equal({ 'ice_breakers' => breakers }, transport.last.json)
    assert_empty client.accounts.delete_ice_breakers('acc_1').ice_breakers
  end

  def test_persistent_menu_round_trip
    menu = [{ 'locale' => 'default',
              'call_to_actions' => [
                { 'type' => 'postback', 'title' => 'Talk to Us', 'payload' => 'HUMAN' },
                { 'type' => 'web_url', 'title' => 'Shop', 'url' => 'https://example.com/shop' }
              ] }]
    body = { 'data' => { 'persistent_menu' => menu } }
    transport.stub(:put, '/accounts/acc_1/messaging/persistent-menu', json: body)
    transport.stub(:get, '/accounts/acc_1/messaging/persistent-menu', json: body)

    saved = client.accounts.set_persistent_menu('acc_1', [{ locale: 'default',
                                                            call_to_actions: [
                                                              { type: 'postback', title: 'Talk to Us',
                                                                payload: 'HUMAN' },
                                                              { type: 'web_url', title: 'Shop',
                                                                url: 'https://example.com/shop' }
                                                            ] }])

    assert_equal({ 'persistent_menu' => menu }, transport.last.json)
    assert_equal 'HUMAN', saved.persistent_menu[0].call_to_actions[0].payload

    read = client.accounts.get_persistent_menu('acc_1')

    assert_equal 'https://example.com/shop', read.persistent_menu[0].call_to_actions[1].url
  end

  def test_greeting_defaults_the_locale
    greeting = [{ 'locale' => 'default', 'text' => 'Hi! Ask us anything.' }]
    transport.stub(:put, '/accounts/acc_1/messaging/greeting', json: { 'data' => { 'greeting' => greeting } })

    saved = client.accounts.set_greeting('acc_1', [{ text: 'Hi! Ask us anything.' }])

    assert_equal({ 'greeting' => greeting }, transport.last.json)
    assert_equal 'default', saved.greeting[0].locale
  end

  def test_webhook_subscription_reports_and_resubscribes
    transport.stub(:get, '/accounts/acc_1/webhook-subscription',
                   json: { 'data' => { 'subscribed' => false, 'fields' => ['feed'],
                                       'missing_fields' => ['messages'] } })
    transport.stub(:post, '/accounts/acc_1/webhook-subscription',
                   json: { 'data' => { 'subscribed' => true, 'fields' => %w[feed messages],
                                       'missing_fields' => [] } })

    lapsed = client.accounts.get_webhook_subscription('acc_1')

    refute lapsed.subscribed
    assert_equal ['messages'], lapsed.missing_fields

    assert client.accounts.resubscribe_webhook('acc_1').subscribed
  end

  def test_handover_passes_and_takes_control
    transport.stub(:post, '/inbox/conversations/t_1/handover',
                   json: { 'data' => { 'app_id' => '263902037430900', 'control' => 'passed' } })
    transport.stub(:post, '/inbox/conversations/t_1/handover',
                   json: { 'data' => { 'app_id' => nil, 'control' => 'taken' } })

    passed = client.inbox.handover('t_1', account_id: 'acc_1', app_id: '263902037430900')

    assert_equal 'passed', passed.control
    assert_equal({ 'account_id' => 'acc_1', 'app_id' => '263902037430900' }, transport.last.json)

    taken = client.inbox.handover('t_1', account_id: 'acc_1')

    assert_equal({ 'account_id' => 'acc_1' }, transport.last.json)
    assert_nil taken.app_id
  end
end
