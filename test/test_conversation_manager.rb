require_relative 'test_helper'

class TestConversationManager < Minitest::Test
  def setup
    @manager = ConversationManager.new(5) # max 5 messages
  end

  def test_empty_history_for_new_user
    assert_equal [], @manager.get_history(1)
  end

  def test_add_and_retrieve_message
    @manager.add_message(1, 'user', 'Hello')
    history = @manager.get_history(1)
    assert_equal 1, history.length
    assert_equal 'user', history[0][:role]
    assert_equal 'Hello', history[0][:content]
  end

  def test_add_multiple_messages
    @manager.add_message(1, 'user', 'Hello')
    @manager.add_message(1, 'assistant', 'Hi there')
    @manager.add_message(1, 'user', 'How are you?')

    history = @manager.get_history(1)
    assert_equal 3, history.length
    assert_equal 'user', history[0][:role]
    assert_equal 'assistant', history[1][:role]
    assert_equal 'user', history[2][:role]
  end

  def test_max_history_limit
    10.times { |i| @manager.add_message(1, 'user', "Message #{i}") }
    history = @manager.get_history(1)
    assert_equal 5, history.length
    assert_equal 'Message 5', history[0][:content]
    assert_equal 'Message 9', history[4][:content]
  end

  def test_clear_history
    @manager.add_message(1, 'user', 'Hello')
    @manager.add_message(1, 'assistant', 'Hi')
    assert !@manager.get_history(1).empty?

    @manager.clear_history(1)
    assert_equal [], @manager.get_history(1)
  end

  def test_clear_all
    @manager.add_message(1, 'user', 'Hello')
    @manager.add_message(2, 'user', 'Hi')
    @manager.clear_all
    assert_equal [], @manager.get_history(1)
    assert_equal [], @manager.get_history(2)
  end

  def test_separate_conversations
    @manager.add_message(1, 'user', 'User 1 message')
    @manager.add_message(2, 'user', 'User 2 message')

    history1 = @manager.get_history(1)
    history2 = @manager.get_history(2)

    assert_equal 1, history1.length
    assert_equal 'User 1 message', history1[0][:content]
    assert_equal 'User 2 message', history2[0][:content]
  end

  def test_user_conversation_exists
    assert !@manager.user_conversation_exists?(1)
    @manager.add_message(1, 'user', 'Hello')
    assert @manager.user_conversation_exists?(1)
    @manager.clear_history(1)
    assert !@manager.user_conversation_exists?(1)
  end
end
