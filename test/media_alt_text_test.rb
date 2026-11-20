# frozen_string_literal: true

require 'test_helper'

class MediaAltTextTest < Minitest::Test
  include ClientHelpers

  def test_generate_alt_text_reads_the_result
    transport.stub(:post, '/media/med_1/alt-text', json: {
                     'alt_text' => 'A red bicycle against a white wall', 'alt_text_source' => 'ai',
                     'tags' => %w[bicycle red]
                   })

    result = client.media.generate_alt_text('med_1')

    assert_equal 'POST', transport.last.method
    assert_equal '/v1/media/med_1/alt-text', transport.last.path
    assert_equal 'A red bicycle against a white wall', result.alt_text
    assert_equal 'ai', result.alt_text_source
    assert_equal %w[bicycle red], result.tags
  end

  def test_generate_alt_text_raises_payment_required
    transport.stub(:post, '/media/med_1/alt-text', status: 402, json: {
                     'error' => 'insufficient_credits', 'message' => 'Your AI balance is empty.',
                     'upgrade_url' => '/settings/billing'
                   })

    error = assert_raises(Fopost::PaymentRequiredError) { client.media.generate_alt_text('med_1') }
    assert_equal '/settings/billing', error.upgrade_url
  end

  def test_file_url_asks_for_json
    transport.stub(:get, '/media/med_1/file', json: { 'url' => 'https://files.yourbrand.com/signed' })

    url = client.media.file_url('med_1')

    assert_equal({ 'format' => 'json' }, transport.last.query)
    assert_equal 'https://files.yourbrand.com/signed', url
  end
end
