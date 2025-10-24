class CreateRubyLlmTables < ActiveRecord::Migration[7.0]
  def change
    # Таблица для хранения чатов
    create_table :chats do |t|
      t.string :model, null: false
      t.string :provider
      t.string :title
      t.timestamps
    end

    # Таблица для хранения сообщений
    create_table :messages do |t|
      t.references :chat, null: false, foreign_key: true
      t.string :role, null: false
      t.text :content, null: false
      t.string :model_id
      t.integer :input_tokens
      t.integer :output_tokens
      t.string :tool_call_id
      t.json :metadata
      t.timestamps
    end

    add_index :messages, :role
    add_index :messages, :model_id

    # Таблица для tool calls
    create_table :tool_calls do |t|
      t.references :message, null: false, foreign_key: true
      t.string :name, null: false
      t.json :arguments, null: false
      t.string :tool_call_id
      t.timestamps
    end
  end
end