# frozen_string_literal: true

class Message < ApplicationRecord
  acts_as_message

  # Ассоциации автоматически добавлены acts_as_message:
  # - belongs_to :chat
  # - has_many :tool_calls
  # - belongs_to :parent_tool_call (для связи с ToolCall)
  # - has_many :tool_results (через tool_calls)
  # - belongs_to :model

  # Валидации
  validates :role, presence: true, inclusion: { in: %w[user assistant system tool] }
  #validates :content, presence: true

  # Scopes
  scope :by_role, ->(role) { where(role: role) }
  scope :user_messages, -> { by_role('user') }
  scope :assistant_messages, -> { by_role('assistant') }
  scope :recent, -> { order(created_at: :asc) }

  # Методы для удобной работы
  def from_user?
    role == 'user'
  end

  def from_assistant?
    role == 'assistant'
  end

  def has_tool_calls?
    tool_calls.any?
  end

  def truncated_content(length = 100)
    return content if content.length <= length
    content.truncate(length) + '...'
  end
end
