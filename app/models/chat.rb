# frozen_string_literal: true

class Chat < ApplicationRecord
  acts_as_chat

  # Telegram ассоциации
  belongs_to :telegram_user,
             class_name: 'TelegramUser',
             optional: true,
             foreign_key: 'telegram_user_id',
             primary_key: 'telegram_id'

  # Валидации
  validates :model, presence: true
  validates :telegram_user_id, uniqueness: { scope: :telegram_chat_id }, allow_nil: true

  # Scopes
  scope :by_telegram_user, ->(user_id) { where(telegram_user_id: user_id) }
  scope :recent, -> { order(updated_at: :desc) }

  # Методы для удобной работы
  def telegram_display_name
    return telegram_user&.display_name if telegram_user

    parts = [telegram_first_name, telegram_last_name].compact
    parts.any? ? parts.join(' ') : "User ##{telegram_user_id}"
  end

  def self.find_or_create_by_telegram_user(user_info)
    user_id = user_info[:id]
    chat_id = user_info[:chat_id] || user_id

    find_by(telegram_user_id: user_id, telegram_chat_id: chat_id) ||
      create!(
        telegram_user_id: user_id,
        telegram_chat_id: chat_id,
        telegram_username: user_info[:username],
        telegram_first_name: user_info[:first_name],
        telegram_last_name: user_info[:last_name],
        model: AppConfig.llm_model,
        provider: AppConfig.llm_provider
      )
  end
end
