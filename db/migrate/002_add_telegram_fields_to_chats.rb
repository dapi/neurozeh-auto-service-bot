class AddTelegramFieldsToChats < ActiveRecord::Migration[7.0]
  def change
    add_column :chats, :telegram_user_id, :integer
    add_column :chats, :telegram_chat_id, :integer
    add_column :chats, :telegram_username, :string
    add_column :chats, :telegram_first_name, :string
    add_column :chats, :telegram_last_name, :string

    add_index :chats, :telegram_user_id
    add_index :chats, :telegram_chat_id
    add_index :chats, :telegram_username
  end
end