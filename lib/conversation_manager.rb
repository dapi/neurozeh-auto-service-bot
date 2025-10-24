# frozen_string_literal: true

class ConversationManager
  # Получить или создать чат для пользователя
  def get_or_create_chat(user_info)
    Application.logger.debug "Getting or creating chat for user #{user_info[:id]}"

    chat = Chat.find_or_create_by_telegram_user(user_info)

    # Установить модель если новая запись
    #if chat.new_record? || chat.model.blank?
      #chat.update!(
        #model: AppConfig.llm_model,
        #provider: AppConfig.llm_provider
      #)
    #end

    chat
  end

  # Получить историю диалога в формате [ {role: 'user', content: '...'} ]
  def get_history(user_id)
    chat = Chat.find_by(telegram_user_id: user_id)
    return [] unless chat

    # Используем ActiveRecord ассоциацию для получения истории
    chat.messages.order(created_at: :asc).map do |message|
      {
        role: message.role,
        content: message.content,
        created_at: message.created_at,
        tokens: {
          input: message.input_tokens,
          output: message.output_tokens
        }
      }
    end
  end

  # Добавить сообщение в историю (только для совместимости)
  # РЕАЛИЗАЦИЯ УДАЛЕНА: RubyLLM автоматически сохраняет сообщения при использовании chat.ask
  # Этот метод оставлен для совместимости с существующим кодом
  def add_message(user_id, role, content)
    Application.logger.debug "Legacy add_message called for user #{user_id}, role: #{role} - NO-OP (handled by RubyLLM)"
  end

  # Очистить историю пользователя
  def clear_history(user_id)
    chat = Chat.find_by(telegram_user_id: user_id)
    return false unless chat

    Message.where(chat_id: chat.id).destroy_all
    Application.logger.info "Cleared history for user #{user_id}"
    true
  end

  # Очистить все истории
  def clear_all
    Message.destroy_all
    Chat.destroy_all
    Application.logger.info "Cleared all conversation history"
  end

  # Проверить существование диалога
  def user_conversation_exists?(user_id)
    Chat.exists?(telegram_user_id: user_id)
  end

  # Получить статистику
  def get_stats
    {
      total_users: Chat.distinct.count(:telegram_user_id),
      total_chats: Chat.count,
      total_messages: Message.count,
      total_tokens: Message.sum(:input_tokens) + Message.sum(:output_tokens)
    }
  end

  # Получить активных пользователей за последние N дней
  def get_active_users(days = 7)
    Chat.joins(:messages)
        .where('messages.created_at > ?', days.days.ago)
        .distinct
        .count(:telegram_user_id)
  end

  # Найти чаты с ошибками (например, без ответа)
  def find_problematic_chats
    Chat.joins(:messages)
        .where(messages: { role: 'user' })
        .where.not(id: Message.where(role: 'assistant').select(:chat_id))
        .includes(:messages)
  end

  # Очистка старых сообщений
  def cleanup_old_messages(days_to_keep = 30)
    cutoff_date = days_to_keep.days.ago

    old_messages = Message.where('created_at < ?', cutoff_date)
    count = old_messages.count

    old_messages.destroy_all

    # Удаляем пустые чаты
    Chat.where.missing(:messages).destroy_all

    Application.logger.info "Cleaned up #{count} old messages older than #{days_to_keep} days"
    count
  end

  # Экспорт данных пользователя
  def export_user_data(user_id)
    chat = Chat.find_by(telegram_user_id: user_id)
    return nil unless chat

    {
      user: {
        id: chat.telegram_user_id,
        username: chat.telegram_username,
        first_name: chat.telegram_first_name,
        last_name: chat.telegram_last_name
      },
      messages: chat.messages.recent.map do |msg|
        {
          role: msg.role,
          content: msg.content,
          created_at: msg.created_at,
          tokens: {
            input: msg.input_tokens,
            output: msg.output_tokens
          }
        }
      end
    }
  end

  # Аналитика использования
  def get_usage_analytics(days = 7)
    start_date = days.days.ago

    {
      total_users: Chat.joins(:messages)
                       .where('messages.created_at > ?', start_date)
                       .distinct
                       .count(:telegram_user_id),
      total_messages: Message.where('created_at > ?', start_date).count,
      total_tokens: Message.where('created_at > ?', start_date)
                          .sum(:input_tokens + :output_tokens),
      average_messages_per_user: Message.where('created_at > ?', start_date)
                                       .group(:chat_id)
                                       .average(:id)&.values&.sum&.to_f /
                                       Chat.joins(:messages)
                                           .where('messages.created_at > ?', start_date)
                                           .distinct
                                           .count || 0
    }
  end
end
