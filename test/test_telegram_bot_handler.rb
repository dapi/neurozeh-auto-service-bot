# frozen_string_literal: true

require 'test_helper'
require 'telegram/bot'

class TestTelegramBotHandler < Minitest::Test
  def setup
    # Set up environment variables for anyway_config
    ENV['ANTHROPIC_AUTH_TOKEN'] = 'test_token'
    ENV['TELEGRAM_BOT_TOKEN'] = 'test_bot_token'
    ENV['SYSTEM_PROMPT_PATH'] = './config/system-prompt.md'
    ENV['WELCOME_MESSAGE_PATH'] = './config/welcome-message.md'

    @config = AppConfig.new

    @claude_client = Minitest::Mock.new
    @rate_limiter = Minitest::Mock.new
    @conversation_manager = Minitest::Mock.new
    @logger = Minitest::Mock.new

    @handler = TelegramBotHandler.new(
      @config,
      @claude_client,
      @rate_limiter,
      @conversation_manager,
      @logger
    )
  end

  def teardown
    # Очистка переменных окружения
    ENV.delete('ANTHROPIC_AUTH_TOKEN')
    ENV.delete('TELEGRAM_BOT_TOKEN')
    ENV.delete('SYSTEM_PROMPT_PATH')
    ENV.delete('WELCOME_MESSAGE_PATH')
  end

  def test_read_welcome_message_success
    # Test reading welcome message from file successfully
    welcome_text = @handler.send(:read_welcome_message)

    refute_empty welcome_text
    assert_includes welcome_text, 'Добро пожаловать в автосервис "Кузник"'
  end

  def test_read_welcome_message_fallback_on_error
    # Mock File.read to raise an error and logger to expect error call
    File.stub(:read, ->(_path) { raise StandardError, 'File error' }) do
      @logger.expect(:error, nil, [/Error reading welcome message/])

      welcome_text = @handler.send(:read_welcome_message)

      assert_equal 'Привет! Я бот для записи на услуги автосервиса. Чем я могу вам помочь?', welcome_text
      @logger.verify
    end
  end

  def test_start_command_with_welcome_message
    # Mock bot API
    bot = Minitest::Mock.new
    bot_api = Minitest::Mock.new

    bot.expect(:api, bot_api)
    bot_api.expect(:send_message, nil) do |args|
      assert_includes args[:text], 'Добро пожаловать в автосервис "Кузник"'
      assert_equal 'Markdown', args[:parse_mode]
      true
    end

    # Mock conversation manager
    @conversation_manager.expect(:clear_history, nil, [123])

    # Create test message
    message = Minitest::Mock.new
    message.expect(:from, OpenStruct.new(id: 123))
    message.expect(:text, '/start')
    message.expect(:chat, OpenStruct.new(id: 456))

    # Mock logger
    @logger.expect(:info, nil, [/Received message/])
    @logger.expect(:info, nil, [%r{issued /start command}])

    @handler.send(:process_message, message, bot)

    message.verify
    bot.verify
    bot_api.verify
    @conversation_manager.verify
    @logger.verify
  end

  def test_config_includes_welcome_message_path
    assert_equal './config/welcome-message.md', @config.welcome_message_path
  end

  def test_welcome_message_file_exists
    assert File.exist?(@config.welcome_message_path)
    assert File.readable?(@config.welcome_message_path)
  end
end
