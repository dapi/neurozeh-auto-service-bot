# frozen_string_literal: true

class TelegramUser < ApplicationRecord
  self.primary_key = 'telegram_id'

  has_many :chats, foreign_key: 'telegram_user_id', primary_key: 'telegram_id'

  validates :telegram_id, presence: true, uniqueness: true

  def display_name
    return username if username.present?

    parts = [first_name, last_name].compact
    parts.any? ? parts.join(' ') : "User ##{telegram_id}"
  end

  def full_name
    [first_name, last_name].compact.join(' ')
  end
end