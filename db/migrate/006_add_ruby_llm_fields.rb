# frozen_string_literal: true

class AddRubyLlmFields < ActiveRecord::Migration[8.0]
  def change
    # Добавляем поле model_id в chats для связи с моделью AI
    # acts_as_chat ожидает foreign_key для ассоциации с model
    # Используем string, так как model_id в таблице models это string
    unless column_exists?(:chats, :model_id)
      add_column :chats, :model_id, :string, null: true
      add_index :chats, :model_id
      # Внешний ключ не добавляем, так как models.model_id не primary key
    end

    # Добавляем поле parent_tool_call_id в messages для связи с ToolCall
    # acts_as_message создает belongs_to :parent_tool_call
    unless column_exists?(:messages, :parent_tool_call_id)
      add_reference :messages, :parent_tool_call, null: true, foreign_key: { to_table: :tool_calls }
      add_index :messages, :parent_tool_call_id unless index_exists?(:messages, :parent_tool_call_id)
    end
  end
end