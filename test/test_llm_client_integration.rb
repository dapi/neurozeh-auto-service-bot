# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../lib/llm_client'

class TestLLMClientIntegration < Minitest::Test
  def setup
    # Use real config instead of mock to avoid complex expectations
    ENV['LLM_PROVIDER'] = 'openai'
    ENV['LLM_MODEL'] = 'gpt-3.5-turbo'
    ENV['OPENAI_API_BASE'] = ''
    ENV['SYSTEM_PROMPT_PATH'] = './data/system-prompt.md'
    ENV['COMPANY_INFO_PATH'] = './data/company-info.md'
    ENV['PRICE_LIST_PATH'] = './data/price.csv'
    ENV['ADMIN_CHAT_ID'] = '123456789'
    ENV['TELEGRAM_BOT_TOKEN'] = 'test_token'

    @config = Application.config
    @logger = NullLogger.new
    @client = LLMClient.new(@config, @logger)
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

    RubyLLM.stub(:chat, chat_mock) do
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

    # Mock RubyLLM.chat with tool support
    chat_mock = Minitest::Mock.new
    chat_mock.expect :with_instructions, chat_mock, [String, { replace: true }]
    chat_mock.expect :with_tool, chat_mock, [RequestDetector]
    chat_mock.expect :ask, Minitest::Mock.new, [String]

    RubyLLM.stub(:chat, chat_mock) do
      response = @client.send_message(messages, user_info)
      assert response.is_a?(String)
    end
  end

  def test_send_message_with_user_info_no_admin_chat
    # Create config without admin_chat_id
    config_no_admin = Minitest::Mock.new
    config_no_admin.expect :llm_provider, 'openai'
    config_no_admin.expect :llm_model, 'gpt-3.5-turbo'
    config_no_admin.expect :openai_api_base, nil
    config_no_admin.expect :system_prompt, 'Test system prompt'
    config_no_admin.expect :company_info, 'Test company info'
    config_no_admin.expect :formatted_price_list, 'Test price list'
    config_no_admin.expect :admin_chat_id, nil
    config_no_admin.expect :telegram_bot_token, 'test_token'

    client_no_admin = LLMClient.new(config_no_admin, NullLogger.new)

    user_info = { id: 123, username: 'test' }

    # Mock RubyLLM.chat without tools (since admin_chat_id is nil)
    chat_mock = Minitest::Mock.new
    chat_mock.expect :with_instructions, chat_mock, [String, { replace: true }]
    chat_mock.expect :ask, Minitest::Mock.new, ['Test message']

    RubyLLM.stub(:chat, chat_mock) do
      response = client_no_admin.send_message([{ role: 'user', content: 'Test message' }], user_info)
      assert response.is_a?(String)
    end

    config_no_admin.verify
  end

  def test_request_detector_tool_integration
    user_info = { id: 999, username: 'test_user', first_name: 'Test' }

    # Mock RequestDetector that returns an error
    request_detector_mock = Minitest::Mock.new
    request_detector_mock.expect :execute, { error: 'Admin chat not configured' }

    RequestDetector.stub(:new, request_detector_mock) do
      # Mock RubyLLM.chat
      chat_mock = Minitest::Mock.new
      chat_mock.expect :with_instructions, chat_mock, [String, { replace: true }]
      chat_mock.expect :with_tool, chat_mock, [request_detector_mock]
      chat_mock.expect :ask, Minitest::Mock.new, ['Записаться на диагностику']

      RubyLLM.stub(:chat, chat_mock) do
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

    chat_mock = Minitest::Mock.new
    chat_mock.expect :with_instructions, chat_mock, [String, { replace: true }]
    chat_mock.expect :with_tool, chat_mock, [RequestDetector]

    # Verify that conversation context is passed correctly
    expected_context = "user: My car makes strange noise\nassistant: What kind of noise?\nuser: It is a grinding noise when braking"

    chat_mock.expect :with_tool_params, chat_mock do |detector, params|
      params[:conversation_context] == expected_context
    end

    chat_mock.expect :ask, Minitest::Mock.new, [String]

    RubyLLM.stub(:chat, chat_mock) do
      response = @client.send_message(messages, user_info)
      assert response.is_a?(String)
    end
  end
end