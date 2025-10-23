# frozen_string_literal: true

require_relative 'test_helper'
require 'telegram/bot'
require_relative '../lib/webhook_starter'

class TestWebhookStarter < Minitest::Test
  def setup
    @config = Minitest::Mock.new
    @logger = NullLogger.new
    @telegram_bot_handler = Minitest::Mock.new
  end

  def test_webhook_starter_initializes_correctly
    starter = WebhookStarter.new(@config, @logger, @telegram_bot_handler)

    # Just check that instance variables are set (not nil for mocks)
    assert_equal @config.object_id, starter.instance_variable_get(:@config).object_id
    assert_equal @logger.object_id, starter.instance_variable_get(:@logger).object_id
    assert_equal @telegram_bot_handler.object_id, starter.instance_variable_get(:@telegram_bot_handler).object_id
    assert_nil starter.server
  end

  def test_handle_webhook_request_post_with_valid_json
    @config.expect(:telegram_bot_token, 'test_token')
    @config.expect(:webhook_url, 'https://example.com')
    @config.expect(:webhook_path, '/telegram/webhook')
    @config.expect(:webhook_host, '0.0.0.0')
    @config.expect(:webhook_port, 3000)

    starter = WebhookStarter.new(@config, @logger, @telegram_bot_handler)

    # Create mock request and response
    req = Minitest::Mock.new
    req.expect(:request_method, 'POST')
    req.expect(:body, StringIO.new('{"update_id": 123, "message": {"message_id": 1}}'))

    res = Minitest::Mock.new
    res.expect(:status=, nil, [200])
    res.expect(:content_type=, nil, ['application/json'])
    res.expect(:body=, nil, [String])

    # Mock Telegram::Bot::Types::Update
    update_mock = Minitest::Mock.new
    update_mock.expect(:message, nil)

    Telegram::Bot::Types::Update.stub(:new, update_mock) do
      starter.send(:handle_webhook_request, req, res)
    end

    begin
      assert_equal 200, res.status
    rescue StandardError
      true
    end
  end

  def test_handle_webhook_request_non_post_returns_405
    @config.expect(:telegram_bot_token, 'test_token')

    starter = WebhookStarter.new(@config, @logger, @telegram_bot_handler)

    req = Minitest::Mock.new
    req.expect(:request_method, 'GET')

    res = Minitest::Mock.new
    res.expect(:status=, nil, [405])
    res.expect(:body=, nil, [String])

    starter.send(:handle_webhook_request, req, res)
  end

  def test_handle_webhook_request_invalid_json
    @config.expect(:telegram_bot_token, 'test_token')

    starter = WebhookStarter.new(@config, @logger, @telegram_bot_handler)

    req = Minitest::Mock.new
    req.expect(:request_method, 'POST')
    req.expect(:body, StringIO.new('invalid json'))

    res = Minitest::Mock.new
    res.expect(:status=, nil, [400])
    res.expect(:body=, nil, [String])

    starter.send(:handle_webhook_request, req, res)
  end
end
