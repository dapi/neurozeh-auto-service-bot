# frozen_string_literal: true

class ConversationManager
  def initialize(max_history = 10)
    @max_history = max_history
    @conversations = {} # { user_id => [{ role: 'user/assistant', content: '...' }] }
    @lock = Mutex.new
  end

  def get_history(user_id)
    @lock.synchronize do
      @conversations[user_id] || []
    end
  end

  def add_message(user_id, role, content)
    @lock.synchronize do
      @conversations[user_id] ||= []
      @conversations[user_id] << { role: role, content: content }

      # Keep only the last N messages
      @conversations[user_id] = @conversations[user_id].last(@max_history)
    end
  end

  def clear_history(user_id)
    @lock.synchronize do
      @conversations.delete(user_id)
    end
  end

  def clear_all
    @lock.synchronize do
      @conversations.clear
    end
  end

  def user_conversation_exists?(user_id)
    @lock.synchronize do
      @conversations.key?(user_id) && !@conversations[user_id].empty?
    end
  end
end
