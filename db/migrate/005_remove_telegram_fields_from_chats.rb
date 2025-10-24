# frozen_string_literal: true

class RemoveTelegramFieldsFromChats < ActiveRecord::Migration[7.0]
  def change
    remove_column :chats, :telegram_username, :string
    remove_column :chats, :telegram_first_name, :string
    remove_column :chats, :telegram_last_name, :string
  end
end