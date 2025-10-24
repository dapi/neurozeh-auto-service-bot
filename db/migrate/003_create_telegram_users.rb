class CreateTelegramUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :telegram_users, id: false do |t|
      t.integer :telegram_id, primary_key: true
      t.string :username
      t.string :first_name
      t.string :last_name
      t.boolean :is_bot, default: false
      t.string :language_code
      t.timestamps
    end

    add_index :telegram_users, :username
  end
end