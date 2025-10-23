# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../lib/bot_launcher'
require_relative '../lib/polling_starter'
require_relative '../lib/webhook_starter'

class TestBotLauncher < Minitest::Test
  def setup
    @config = Minitest::Mock.new
    @logger = NullLogger.new
    @telegram_bot_handler = Minitest::Mock.new
  end

  def test_polling_mode_creates_polling_starter
    @config.expect(:bot_mode, 'polling')
    @config.expect(:bot_mode, 'polling')

    launcher = BotLauncher.new(@config, @logger, @telegram_bot_handler)

    # Mock PollingStarter
    polling_starter_mock = Minitest::Mock.new
    polling_starter_mock.expect(:start, nil)

    PollingStarter.stub(:new, polling_starter_mock) do
      launcher.start
    end

    polling_starter_mock.verify
  end

  def test_webhook_mode_creates_webhook_starter
    @config.expect(:bot_mode, 'webhook')
    @config.expect(:bot_mode, 'webhook')

    launcher = BotLauncher.new(@config, @logger, @telegram_bot_handler)

    # Mock WebhookStarter
    webhook_starter_mock = Minitest::Mock.new
    webhook_starter_mock.expect(:start, nil)

    WebhookStarter.stub(:new, webhook_starter_mock) do
      launcher.start
    end

    webhook_starter_mock.verify
  end

  def test_unknown_mode_raises_error
    launcher = BotLauncher.new(@config, @logger, @telegram_bot_handler)

    # Set up expectations for multiple calls to bot_mode
    3.times { @config.expect(:bot_mode, 'invalid') }

    assert_raises(RuntimeError, 'Unknown bot mode: invalid') do
      launcher.start
    end
  end
end
