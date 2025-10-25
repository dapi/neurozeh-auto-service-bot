# frozen_string_literal: true

class Chat < ApplicationRecord
  acts_as_chat

  # Ассоциации автоматически добавлены acts_as_chat:
  # - has_many :messages
  # - belongs_to :model (ссылается на модель AI через model_id)

  # Telegram ассоциации
  belongs_to :telegram_user,
             class_name: 'TelegramUser',
             optional: true,
             foreign_key: 'telegram_user_id',
             primary_key: 'telegram_id'

  # Валидации
  validates :telegram_user_id, uniqueness: { scope: :telegram_chat_id }, allow_nil: true

  # Scopes
  scope :by_telegram_user, ->(user_id) { where(telegram_user_id: user_id) }
  scope :recent, -> { order(updated_at: :desc) }

  # Методы для удобной работы
  def telegram_display_name
    telegram_user&.display_name || "User ##{telegram_user_id}"
  end

  def self.find_or_create_by_telegram_user(user_info)
    user_id = user_info[:id]
    chat_id = user_info[:chat_id] || user_id

    find_or_create_by!(telegram_user_id: user_id, telegram_chat_id: chat_id)
  end
end
