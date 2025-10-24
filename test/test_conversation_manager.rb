# frozen_string_literal: true

require_relative 'test_helper'

class TestConversationManager < Minitest::Test
  def setup
    DatabaseCleaner.clean
    super
    @manager = ConversationManager.new
  end

  def test_empty_history_for_new_user
    assert_empty @manager.get_history(1)
  end

  def test_add_and_retrieve_message
    user_info = { id: 1, first_name: 'Test', username: 'test' }
    chat = @manager.get_or_create_chat(user_info)

    # Создаем сообщение напрямую через базу данных
    Message.create!(
      chat_id: chat.id,
      role: 'user',
      content: 'Hello',
      input_tokens: 10,
      output_tokens: 0
    )

    history = @manager.get_history(1)
    assert_equal 1, history.length
    assert_equal 'user', history[0][:role]
    assert_equal 'Hello', history[0][:content]
  end

  def test_add_multiple_messages
    user_info = { id: 1, first_name: 'Test', username: 'test' }
    chat = @manager.get_or_create_chat(user_info)

    # Создаем несколько сообщений
    Message.create!(chat_id: chat.id, role: 'user', content: 'Hello', input_tokens: 10, output_tokens: 0)
    Message.create!(chat_id: chat.id, role: 'assistant', content: 'Hi there', input_tokens: 0, output_tokens: 15)
    Message.create!(chat_id: chat.id, role: 'user', content: 'How are you?', input_tokens: 12, output_tokens: 0)

    history = @manager.get_history(1)
    assert_equal 3, history.length
    assert_equal 'user', history[0][:role]
    assert_equal 'assistant', history[1][:role]
    assert_equal 'user', history[2][:role]
  end

  def test_max_history_limit
    # В новой реализации нет ограничения количества сообщений в менеджере
    # Ограничения могут быть на уровне базы данных или приложения
    user_info = { id: 1, first_name: 'Test', username: 'test' }
    chat = @manager.get_or_create_chat(user_info)

    10.times do |i|
      Message.create!(chat_id: chat.id, role: 'user', content: "Message #{i}", input_tokens: 10, output_tokens: 0)
    end

    history = @manager.get_history(1)
    assert_equal 10, history.length
    assert_equal 'Message 0', history[0][:content]
    assert_equal 'Message 9', history[9][:content]
  end

  def test_clear_history
    user_info = { id: 1, first_name: 'Test', username: 'test' }
    chat = @manager.get_or_create_chat(user_info)

    Message.create!(chat_id: chat.id, role: 'user', content: 'Hello', input_tokens: 10, output_tokens: 0)
    Message.create!(chat_id: chat.id, role: 'assistant', content: 'Hi', input_tokens: 0, output_tokens: 5)
    refute_empty @manager.get_history(1)

    result = @manager.clear_history(1)
    assert_equal true, result
    assert_empty @manager.get_history(1)
  end

  def test_clear_all
    user1_info = { id: 1, first_name: 'Test1', username: 'test1' }
    user2_info = { id: 2, first_name: 'Test2', username: 'test2' }

    chat1 = @manager.get_or_create_chat(user1_info)
    chat2 = @manager.get_or_create_chat(user2_info)

    Message.create!(chat_id: chat1.id, role: 'user', content: 'Hello', input_tokens: 10, output_tokens: 0)
    Message.create!(chat_id: chat2.id, role: 'user', content: 'Hi', input_tokens: 8, output_tokens: 0)

    refute_empty @manager.get_history(1)
    refute_empty @manager.get_history(2)

    @manager.clear_all
    assert_empty @manager.get_history(1)
    assert_empty @manager.get_history(2)
  end

  def test_separate_conversations
    user1_info = { id: 1, first_name: 'Test1', username: 'test1' }
    user2_info = { id: 2, first_name: 'Test2', username: 'test2' }

    chat1 = @manager.get_or_create_chat(user1_info)
    chat2 = @manager.get_or_create_chat(user2_info)

    Message.create!(chat_id: chat1.id, role: 'user', content: 'User 1 message', input_tokens: 15, output_tokens: 0)
    Message.create!(chat_id: chat2.id, role: 'user', content: 'User 2 message', input_tokens: 14, output_tokens: 0)

    history1 = @manager.get_history(1)
    history2 = @manager.get_history(2)

    assert_equal 1, history1.length
    assert_equal 'User 1 message', history1[0][:content]
    assert_equal 1, history2.length
    assert_equal 'User 2 message', history2[0][:content]
  end

  def test_user_conversation_exists
    refute @manager.user_conversation_exists?(1)

    user_info = { id: 1, first_name: 'Test', username: 'test' }
    @manager.get_or_create_chat(user_info)
    assert @manager.user_conversation_exists?(1)

    @manager.clear_history(1)
    # Чат остается даже после очистки сообщений
    assert @manager.user_conversation_exists?(1)
  end
end
