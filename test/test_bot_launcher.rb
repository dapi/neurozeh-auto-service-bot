# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../lib/bot_launcher'
require_relative '../lib/polling_starter'
require_relative '../lib/webhook_starter'

class TestBotLauncher < Minitest::Test
  def setup
    @telegram_bot_handler = Minitest::Mock.new
  end

  def test_polling_mode_creates_polling_starter
    # Mock AppConfig and Application.logger
    AppConfig.stub(:bot_mode, 'polling') do
      Application.logger.stub(:info, nil) do
        launcher = BotLauncher.new(@telegram_bot_handler)

        # Mock PollingStarter
        polling_starter_mock = Minitest::Mock.new
        polling_starter_mock.expect(:start, nil)

        PollingStarter.stub(:new, polling_starter_mock) do
          launcher.start
        end

        polling_starter_mock.verify
      end
    end
  end

  def test_webhook_mode_creates_webhook_starter
    # Mock AppConfig to return 'webhook'
    AppConfig.stub(:bot_mode, 'webhook') do
      Application.logger.stub(:info, nil) do
        launcher = BotLauncher.new(@telegram_bot_handler)

        # Mock WebhookStarter
        webhook_starter_mock = Minitest::Mock.new
        webhook_starter_mock.expect(:start, nil)

        WebhookStarter.stub(:new, webhook_starter_mock) do
          launcher.start
        end

        webhook_starter_mock.verify
      end
    end
  end

  def test_unknown_mode_raises_error
    # Mock AppConfig to return 'invalid'
    AppConfig.stub(:bot_mode, 'invalid') do
      Application.logger.stub(:info, nil) do
        launcher = BotLauncher.new(@telegram_bot_handler)

        assert_raises(RuntimeError, 'Unknown bot mode: invalid') do
          launcher.start
        end
      end
    end
  end
end
