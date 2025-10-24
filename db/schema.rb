# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.0].define(version: 3) do
  create_table "chats", force: :cascade do |t|
    t.string "model", null: false
    t.string "provider"
    t.string "title"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "telegram_user_id"
    t.integer "telegram_chat_id"
    t.string "telegram_username"
    t.string "telegram_first_name"
    t.string "telegram_last_name"
    t.index ["telegram_chat_id"], name: "index_chats_on_telegram_chat_id"
    t.index ["telegram_user_id"], name: "index_chats_on_telegram_user_id"
    t.index ["telegram_username"], name: "index_chats_on_telegram_username"
  end

  create_table "messages", force: :cascade do |t|
    t.integer "chat_id", null: false
    t.string "role", null: false
    t.text "content", null: false
    t.string "model_id"
    t.integer "input_tokens"
    t.integer "output_tokens"
    t.string "tool_call_id"
    t.json "metadata"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["chat_id"], name: "index_messages_on_chat_id"
    t.index ["model_id"], name: "index_messages_on_model_id"
    t.index ["role"], name: "index_messages_on_role"
  end

  create_table "telegram_users", primary_key: "telegram_id", force: :cascade do |t|
    t.string "username"
    t.string "first_name"
    t.string "last_name"
    t.boolean "is_bot", default: false
    t.string "language_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["username"], name: "index_telegram_users_on_username"
  end

  create_table "tool_calls", force: :cascade do |t|
    t.integer "message_id", null: false
    t.string "name", null: false
    t.json "arguments", null: false
    t.string "tool_call_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id"], name: "index_tool_calls_on_message_id"
  end

  add_foreign_key "messages", "chats"
  add_foreign_key "tool_calls", "messages"
end
