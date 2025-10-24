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
    ENV['OPENAI_API_KEY'] = 'test_openai_api_key_12345'
    ENV['LLM_PROVIDER'] = 'anthropic'
    ENV['LLM_MODEL'] = 'claude-3-5-sonnet-20241022'
    ENV['PRICE_LIST_PATH'] = './config/price.csv'

    @config = Application.config

    @ai_client = Minitest::Mock.new
    @rate_limiter = Minitest::Mock.new
    @conversation_manager = Minitest::Mock.new
    @logger = NullLogger.new

    @handler = TelegramBotHandler.new(
      @config,
      @ai_client,
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
    ENV.delete('OPENAI_API_KEY')
    ENV.delete('LLM_PROVIDER')
    ENV.delete('LLM_MODEL')
    ENV.delete('PRICE_LIST_PATH')
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
    message.expect(:new_chat_members, nil)
    message.expect(:group_chat_created, nil)
    message.expect(:supergroup_chat_created, nil)
    message.expect(:channel_chat_created, nil)
    message.expect(:from, OpenStruct.new(id: 123))
    message.expect(:text, '/start')
    message.expect(:chat, OpenStruct.new(id: 456))

    @handler.send(:process_message, message, bot)

    message.verify
    bot.verify
    bot_api.verify
    @conversation_manager.verify
  end

  def test_handle_new_chat_members_with_bot
    # Mock bot API
    bot = Minitest::Mock.new
    bot_api = Minitest::Mock.new

    bot.expect(:api, bot_api)
    bot_api.expect(:send_message, nil) do |args|
      assert_includes args[:text], 'Я был добавлен в этот чат'
      assert_equal 'Markdown', args[:parse_mode]
      true
    end

    # Create mock objects
    bot_member = OpenStruct.new(is_bot: true)
    user_member = OpenStruct.new(is_bot: false)

    added_by = OpenStruct.new(
      id: 123456,
      first_name: 'Иван',
      last_name: 'Петров',
      username: 'ivan_petrov',
      language_code: 'ru'
    )

    chat = OpenStruct.new(
      id: -1001234567890,
      type: 'supergroup',
      title: 'Автосервис',
      username: 'autoservice_chat'
    )

    # Create test message with new_chat_members
    message = Minitest::Mock.new
    message.expect(:new_chat_members, [bot_member, user_member])
    message.expect(:from, added_by)
    message.expect(:chat, chat)

    @handler.send(:handle_new_chat_members, message, bot)

    message.verify
    bot.verify
    bot_api.verify
  end

  def test_handle_new_chat_members_without_bot
    # Create mock objects (only regular users, no bot)
    user1 = OpenStruct.new(is_bot: false)
    user2 = OpenStruct.new(is_bot: false)

    added_by = OpenStruct.new(
      id: 123456,
      first_name: 'Иван',
      last_name: 'Петров'
    )

    chat = OpenStruct.new(
      id: -1001234567890,
      type: 'supergroup',
      title: 'Автосервис'
    )

    # Create test message with new_chat_members (no bot)
    message = Minitest::Mock.new
    message.expect(:new_chat_members, [user1, user2])
    message.expect(:from, added_by)
    message.expect(:chat, chat)

    # Should not log anything if bot is not among new members
    @handler.send(:handle_new_chat_members, message, nil)

    message.verify
  end

  def test_handle_chat_created
    # Mock bot API
    bot = Minitest::Mock.new
    bot_api = Minitest::Mock.new

    bot.expect(:api, bot_api)
    bot_api.expect(:send_message, nil) do |args|
      assert_includes args[:text], 'Я был добавлен в этот чат'
      assert_equal 'Markdown', args[:parse_mode]
      true
    end

    # Create mock objects
    creator = OpenStruct.new(
      id: 987654,
      first_name: 'Мария',
      last_name: 'Иванова',
      username: 'maria_iv'
    )

    chat = OpenStruct.new(
      id: -123456789,
      type: 'group',
      title: 'Новый чат'
    )

    # Create test message for group chat creation
    message = Minitest::Mock.new
    message.expect(:from, creator)
    message.expect(:chat, chat)

    @handler.send(:handle_chat_created, message, bot)

    message.verify
    bot.verify
    bot_api.verify
  end

  def test_handle_chat_member_updated_bot_kicked
    # Test handling bot being removed from chat
    bot = Minitest::Mock.new

    from_user = OpenStruct.new(id: 123456, first_name: 'Иван')
    chat = OpenStruct.new(id: -1001234567890, title: 'Тест чат')

    bot_user = OpenStruct.new(is_bot: true)
    new_member = OpenStruct.new(user: bot_user, status: 'kicked')

    chat_member_update = OpenStruct.new(
      chat: chat,
      from: from_user,
      old_chat_member: OpenStruct.new(user: bot_user, status: 'member'),
      new_chat_member: new_member
    )

    # Mock conversation manager
    @conversation_manager.expect(:clear_history, nil, [-1001234567890])

    @handler.send(:handle_chat_member_updated, chat_member_update, bot)

    @conversation_manager.verify
  end

  def test_handle_chat_member_updated_bot_added
    # Test handling bot being added to chat
    bot = Minitest::Mock.new
    bot_api = Minitest::Mock.new

    bot.expect(:api, bot_api)
    bot_api.expect(:send_message, nil) do |args|
      assert_equal(-1001234567890, args[:chat_id])
      assert_includes args[:text], 'Я был добавлен в этот чат'
      assert_equal 'Markdown', args[:parse_mode]
      true
    end

    from_user = OpenStruct.new(
      id: 123456,
      first_name: 'Иван',
      last_name: 'Петров'
    )
    chat = OpenStruct.new(
      id: -1001234567890,
      title: 'Тест чат',
      type: 'supergroup'
    )

    bot_user = OpenStruct.new(is_bot: true)
    new_member = OpenStruct.new(user: bot_user, status: 'member')

    chat_member_update = OpenStruct.new(
      chat: chat,
      from: from_user,
      old_chat_member: OpenStruct.new(user: bot_user, status: 'left'),
      new_chat_member: new_member
    )

    @handler.send(:handle_chat_member_updated, chat_member_update, bot)

    bot.verify
    bot_api.verify
  end

  def test_handle_chat_member_updated_non_bot_user
    # Test that non-bot user changes are ignored
    bot = Minitest::Mock.new

    from_user = OpenStruct.new(id: 123456, first_name: 'Иван')
    chat = OpenStruct.new(id: -1001234567890)

    regular_user = OpenStruct.new(is_bot: false)
    new_member = OpenStruct.new(user: regular_user, status: 'member')

    chat_member_update = OpenStruct.new(
      chat: chat,
      from: from_user,
      old_chat_member: OpenStruct.new(user: regular_user, status: 'left'),
      new_chat_member: new_member
    )

    @handler.send(:handle_chat_member_updated, chat_member_update, bot)
  end

  def test_handle_chat_member_updated_error_handling
    # Test error handling in chat member updates
    bot = Minitest::Mock.new

    chat_member_update = Minitest::Mock.new
    chat_member_update.expect(:chat, nil) # This will cause an error

    @handler.send(:handle_chat_member_updated, chat_member_update, bot)
  end

  def test_format_chat_info_with_all_fields
    chat = OpenStruct.new(
      id: -1001234567890,
      type: 'supergroup',
      title: 'Автосервис',
      username: 'autoservice_chat'
    )

    added_by = OpenStruct.new(
      id: 123456,
      first_name: 'Иван',
      last_name: 'Петров'
    )

    result = @handler.send(:format_chat_info, chat, added_by)

    assert_includes result, 'Chat ID: -1001234567890'
    assert_includes result, 'Type: supergroup'
    assert_includes result, 'Title: "Автосервис"'
    assert_includes result, 'Username: @autoservice_chat'
    assert_includes result, 'Added by: 123456 (Иван Петров)'
  end

  def test_send_chat_welcome_message_success
    # Mock bot API
    bot = Minitest::Mock.new
    bot_api = Minitest::Mock.new

    bot.expect(:api, bot_api)
    bot_api.expect(:send_message, nil) do |args|
      assert_equal 123, args[:chat_id]
      assert_includes args[:text], 'Я был добавлен в этот чат'
      assert_equal 'Markdown', args[:parse_mode]
      true
    end

    @handler.send(:send_chat_welcome_message, 123, bot)

    bot.verify
    bot_api.verify
  end

  def test_send_chat_welcome_message_error_handling
    # Mock bot API that raises an error
    bot = Minitest::Mock.new
    bot_api = Minitest::Mock.new

    bot.expect(:api, bot_api)
    bot_api.expect(:send_message, nil) { raise StandardError, 'API Error' }

    @handler.send(:send_chat_welcome_message, 123, bot)

    bot.verify
    bot_api.verify
  end
end