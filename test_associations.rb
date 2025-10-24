#!/usr/bin/env ruby
# frozen_string_literal: true

# Simple test script for model associations
require_relative 'test/test_helper'

def test_model_associations
  puts "Testing RubyLLM Model Associations"
  puts "=================================="

  # Test 1: Check Model registry
  puts "\n1. Testing Model registry:"
  deepseek = Model.find_by_model_id('deepseek-chat')
  if deepseek
    puts "✓ DeepSeek model found:"
    puts "  - Model ID: #{deepseek.model_id}"
    puts "  - Provider: #{deepseek.provider}"
    puts "  - Context window: #{deepseek.context_window}"
    puts "  - Supports functions: #{deepseek.supports_functions?}"
  else
    puts "✗ DeepSeek model not found"
    return false
  end

  # Test 2: Test Chat creation
  puts "\n2. Testing Chat creation:"
  begin
    user_info = {
      id: 999999,
      chat_id: 999999,
      username: 'test_user',
      first_name: 'Test',
      last_name: 'User'
    }

    chat = Chat.find_or_create_by_telegram_user(user_info)
    puts "✓ Chat created successfully:"
    puts "  - Chat ID: #{chat.id}"
    puts "  - Telegram User ID: #{chat.telegram_user_id}"
    puts "  - Telegram Chat ID: #{chat.telegram_chat_id}"
    puts "  - Telegram Display Name: #{chat.telegram_display_name}"
  rescue => e
    puts "✗ Chat creation failed: #{e.message}"
    puts e.backtrace.first(3).join("\n")
    return false
  end

  # Test 3: Test Message creation
  puts "\n3. Testing Message creation:"
  begin
    deepseek_model = Model.find_by_model_id('deepseek-chat')
    message = Message.create!(
      chat: chat,
      role: 'user',
      content: 'Test message for model association',
      model: deepseek_model
    )

    puts "✓ Message created successfully:"
    puts "  - Message ID: #{message.id}"
    puts "  - Role: #{message.role}"
    puts "  - Content: #{message.content}"
    puts "  - Model ID: #{message.model_id}"
    puts "  - Model association: #{message.model&.model_id}" if message.model
    puts "  - Model provider: #{message.model&.provider}" if message.model&.provider

    unless message.model
      puts "✗ Message model association is nil"
      return false
    end
  rescue => e
    puts "✗ Message creation failed: #{e.message}"
    puts e.backtrace.first(3).join("\n")
    return false
  end

  puts "\n✓ All model association tests passed!"
  true
end

# Run tests
if test_model_associations
  puts "\n🎉 RubyLLM integration is working correctly!"
  exit 0
else
  puts "\n❌ Model association tests failed!"
  exit 1
end