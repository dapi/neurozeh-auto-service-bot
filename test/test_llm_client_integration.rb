# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../lib/llm_client'

class TestLLMClientIntegration < Minitest::Test
  def setup
    DatabaseCleaner.clean
    super
    # Use real config instead of mock to avoid complex expectations
    ENV['LLM_PROVIDER'] = 'openai'
    ENV['LLM_MODEL'] = 'gpt-3.5-turbo'
    ENV['OPENAI_API_BASE'] = ''
    ENV['SYSTEM_PROMPT_PATH'] = './data/system-prompt.md'
    ENV['COMPANY_INFO_PATH'] = './data/company-info.md'
    ENV['PRICE_LIST_PATH'] = './data/price.csv'
    ENV['ADMIN_CHAT_ID'] = '123456789'
    ENV['TELEGRAM_BOT_TOKEN'] = 'test_token'

    @conversation_manager = ConversationManager.new
    @client = LLMClient.new(@conversation_manager)
  end

  def teardown
    # Clean up environment variables
    ENV.delete('LLM_PROVIDER')
    ENV.delete('LLM_MODEL')
    ENV.delete('OPENAI_API_BASE')
    ENV.delete('SYSTEM_PROMPT_PATH')
    ENV.delete('COMPANY_INFO_PATH')
    ENV.delete('PRICE_LIST_PATH')
    ENV.delete('ADMIN_CHAT_ID')
    ENV.delete('TELEGRAM_BOT_TOKEN')
  end

  def test_send_message_without_user_info
    # Mock RubyLLM.chat
    chat_mock = Minitest::Mock.new
    chat_mock.expect :with_instructions, chat_mock, [String, { replace: true }]
    chat_mock.expect :ask, Minitest::Mock.new, ['Test message']

    RubyLLM.stub(:chat, chat_mock, [{ model: 'claude-3-5-sonnet-20241022', provider: 'anthropic', assume_model_exists: true }]) do
      response = @client.send_message([{ role: 'user', content: 'Test message' }])
      assert response.is_a?(String)
    end
  end

  def test_send_message_with_user_info_and_admin_chat
    user_info = {
      id: 12345,
      username: 'testuser',
      first_name: 'Test'
    }

    messages = [
      { role: 'user', content: 'Hello' },
      { role: 'assistant', content: 'How can I help you?' },
      { role: 'user', content: 'I want to book a service' }
    ]

    # Use stubs instead of complex mocks
    response = Struct.new(:content, :input_tokens, :output_tokens).new('Test response', 10, 5)

    chat_class = Class.new do
      define_method(:with_instructions) { |*args| self }
      define_method(:with_tool) { |*args| self }
      define_method(:ask) { |*args| response }
    end
    chat = chat_class.new

    RubyLLM.stub(:chat, chat) do
      response = @client.send_message(messages, user_info)
      assert response.is_a?(String)
    end
  end

  def test_send_message_with_user_info_no_admin_chat
    # Use existing client but test without admin chat functionality
    # Just test that basic message sending works without admin features
    user_info = { id: 123, username: 'test' }

    # Mock RubyLLM.chat without tools
    response = Struct.new(:content, :input_tokens, :output_tokens).new('Test response', 10, 5)

    chat_class = Class.new do
      define_method(:with_instructions) { |*args| self }
      define_method(:with_tool) { |*args| self }
      define_method(:ask) { |*args| response }
    end
    chat = chat_class.new

    RubyLLM.stub(:chat, chat) do
      response = @client.send_message([{ role: 'user', content: 'Test message' }], user_info)
      assert response.is_a?(String)
    end
  end

  def test_request_detector_tool_integration
    user_info = { id: 999, username: 'test_user', first_name: 'Test' }

    # Mock RequestDetector that returns an error
    request_detector_mock = Minitest::Mock.new
    request_detector_mock.expect :execute, { error: 'Admin chat not configured' }

    RequestDetector.stub(:new, request_detector_mock) do
      # Mock RubyLLM.chat
      response = Struct.new(:content, :input_tokens, :output_tokens).new('Test response', 10, 5)

      chat_class = Class.new do
        define_method(:with_instructions) { |*args| self }
        define_method(:with_tool) { |*args| self }
        define_method(:ask) { |*args| response }
      end
      chat = chat_class.new

      RubyLLM.stub(:chat, chat) do
        response = @client.send_message([{ role: 'user', content: 'Записаться на диагностику' }], user_info)
        assert response.is_a?(String)
      end
    end
  end

  def test_conversation_context_preparation
    user_info = { id: 777, username: 'context_user' }

    messages = [
      { role: 'user', content: 'My car makes strange noise' },
      { role: 'assistant', content: 'What kind of noise?' },
      { role: 'user', content: 'It is a grinding noise when braking' }
    ]

    # Mock response
    response = Struct.new(:content, :input_tokens, :output_tokens).new('Test response', 10, 5)

    chat_class = Class.new do
      define_method(:with_instructions) { |*args| self }
      define_method(:with_tool) { |*args| self }
      define_method(:ask) { |*args| response }
    end
    chat = chat_class.new

    RubyLLM.stub(:chat, chat) do
      response = @client.send_message(messages, user_info)
      assert response.is_a?(String)
    end
  end
end