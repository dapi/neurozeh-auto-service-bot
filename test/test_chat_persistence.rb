# frozen_string_literal: true

require 'test_helper'

class TestChatPersistence < Minitest::Test
  def setup
    # Очищаем тестовую БД перед каждым тестом в правильном порядке
    Message.delete_all
    Chat.delete_all
    TelegramUser.delete_all

    @conversation_manager = ConversationManager.new
  end

  def test_create_chat_for_new_user
    user_info = {
      id: 12345,
      username: 'testuser',
      first_name: 'Test',
      last_name: 'User'
    }

    chat = @conversation_manager.get_or_create_chat(user_info)

    assert chat.persisted?
    assert_equal 12345, chat.telegram_user_id
    assert_equal 'testuser', chat.telegram_username
    assert chat.model.present?
  end

  def test_clear_history
    user_info = { id: 12345 }
    chat = @conversation_manager.get_or_create_chat(user_info)

    # Создаем тестовые сообщения
    Message.create!(chat: chat, role: 'user', content: 'Test message')
    Message.create!(chat: chat, role: 'assistant', content: 'Test response')

    assert_equal 2, Message.where(chat_id: chat.id).count

    result = @conversation_manager.clear_history(12345)
    assert result
    assert_equal 0, Message.where(chat_id: chat.id).count
  end

  def test_get_stats
    user1_info = { id: 12345 }
    user2_info = { id: 67890 }

    @conversation_manager.get_or_create_chat(user1_info)
    @conversation_manager.get_or_create_chat(user2_info)

    stats = @conversation_manager.get_stats

    assert_equal 2, stats[:total_users]
    assert_equal 2, stats[:total_chats]
    assert_equal 0, stats[:total_messages] # Нет сообщений еще
  end
end