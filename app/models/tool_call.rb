# frozen_string_literal: true

class ToolCall < ApplicationRecord
  acts_as_tool_call

  # Ассоциации автоматически добавлены acts_as_tool_call:
  # - belongs_to :message (через message_id)
  # - has_one :result (класса Message, через parent_tool_call_id)

  # Кастомные валидации
  validates :name, presence: true
  validates :arguments, presence: true

  # Методы для удобной работы
  def arguments_hash
    arguments.is_a?(Hash) ? arguments : JSON.parse(arguments || '{}')
  rescue JSON::ParserError
    {}
  end

  def display_name
    name.humanize
  end

  # Проверка содержит ли вызов определенный параметр
  def has_argument?(key)
    arguments_hash.key?(key.to_s)
  end

  # Получить аргумент с преобразованием типа
  def get_argument(key, default = nil)
    args = arguments_hash
    value = args[key.to_s] || args[key.to_sym]
    value || default
  end
end