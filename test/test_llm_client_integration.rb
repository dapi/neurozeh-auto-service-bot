# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../lib/llm_client'

class TestLLMClientIntegration < Minitest::Test
  def setup
    @config = Minitest::Mock.new
    @config.expect :llm_provider, 'openai'
    @config.expect :llm_model, 'gpt-3.5-turbo'
    @config.expect :openai_api_base, nil
    @config.expect :system_prompt, 'Test system prompt'
    @config.expect :company_info, 'Test company info'
    @config.expect :formatted_price_list, 'Test price list'
    @config.expect :admin_chat_id, 123456789
    @config.expect :telegram_bot_token, 'test_token'

    @logger = Minitest::Mock.new
    @client = LLMClient.new(@config, @logger)
  end

  def test_send_message_without_user_info
    @logger.expect :info, nil, ['Sending message to RubyLLM with 1 messages']
    @logger.expect :info, nil, ['LLMClient model: gpt-3.5-turbo, provider: openai (configured as: openai)']
    @logger.expect :debug, nil, ['Last message content: Test message...']
    @logger.expect :debug, nil, ['Sending message to RubyLLM API...']
    @logger.expect :debug, nil, ['Received response from RubyLLM API']

    # Mock RubyLLM.chat
    chat_mock = Minitest::Mock.new
    chat_mock.expect :with_instructions, chat_mock, [kind_of(String), { replace: true }]
    chat_mock.expect :ask, Minitest::Mock.new, ['Test message']

    RubyLLM.stub(:chat, chat_mock) do
      response = @client.send_message([{ role: 'user', content: 'Test message' }])
      assert response.is_a?(String)
    end

    @logger.verify
  end

  def test_send_message_with_user_info_and_admin_chat
    @logger.expect :info, nil, ['Sending message to RubyLLM with 2 messages']
    @logger.expect :info, nil, ['LLMClient model: gpt-3.5-turbo, provider: openai (configured as: openai)']
    @logger.expect :debug, nil, ['Last message content: I want to book a service...']
    @logger.expect :info, nil, ['🔔 REQUEST DETECTED: AI calling tool: request_detector for user 12345']
    @logger.expect :debug, nil, [/Tool arguments: \{.*\}/]
    @logger.expect :info, nil, ['✅ REQUEST SENT: booking for user 12345']
    @logger.expect :debug, nil, ['Sending message to RubyLLM API...']
    @logger.expect :debug, nil, ['Received response from RubyLLM API']

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
    chat_mock.expect :with_instructions, chat_mock, [kind_of(String), { replace: true }]
    chat_mock.expect :with_tool, chat_mock, [kind_of(RequestDetector)]
    chat_mock.expect :on_tool_call, chat_mock
    chat_mock.expect :on_tool_result, chat_mock
    chat_mock.expect :with_tool_params, chat_mock, [kind_of(RequestDetector), kind_of(Hash)]
    chat_mock.expect :ask, Minitest::Mock.new, ['I want to book a service']

    RubyLLM.stub(:chat, chat_mock) do
      response = @client.send_message(messages, user_info)
      assert response.is_a?(String)
    end

    @logger.verify
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

    client_no_admin = LLMClient.new(config_no_admin, @logger)

    @logger.expect :info, nil, ['Sending message to RubyLLM with 1 messages']
    @logger.expect :info, nil, ['LLMClient model: gpt-3.5-turbo, provider: openai (configured as: openai)']
    @logger.expect :debug, nil, ['Last message content: Test message...']
    @logger.expect :debug, nil, ['Sending message to RubyLLM API...']
    @logger.expect :debug, nil, ['Received response from RubyLLM API']

    user_info = { id: 123, username: 'test' }

    # Mock RubyLLM.chat without tools (since admin_chat_id is nil)
    chat_mock = Minitest::Mock.new
    chat_mock.expect :with_instructions, chat_mock, [kind_of(String), { replace: true }]
    chat_mock.expect :ask, Minitest::Mock.new, ['Test message']

    RubyLLM.stub(:chat, chat_mock) do
      response = client_no_admin.send_message([{ role: 'user', content: 'Test message' }], user_info)
      assert response.is_a?(String)
    end

    @logger.verify
    config_no_admin.verify
  end

  def test_request_detector_tool_integration
    @logger.expect :info, nil, ['Sending message to RubyLLM with 1 messages']
    @logger.expect :info, nil, ['LLMClient model: gpt-3.5-turbo, provider: openai (configured as: openai)']
    @logger.expect :debug, nil, ['Last message content: Записаться на диагностику...']
    @logger.expect :info, nil, ['🔔 REQUEST DETECTED: AI calling tool: request_detector for user 999']
    @logger.expect :debug, nil, [/Tool arguments: \{.*\}/]
    @logger.expect :error, nil, ['❌ REQUEST ERROR: Admin chat not configured']
    @logger.expect :debug, nil, ['Sending message to RubyLLM API...']
    @logger.expect :debug, nil, ['Received response from RubyLLM API']

    user_info = { id: 999, username: 'test_user', first_name: 'Test' }

    # Mock RequestDetector that returns an error
    request_detector_mock = Minitest::Mock.new
    request_detector_mock.expect :execute, { error: 'Admin chat not configured' }

    RequestDetector.stub(:new, request_detector_mock) do
      # Mock RubyLLM.chat
      chat_mock = Minitest::Mock.new
      chat_mock.expect :with_instructions, chat_mock, [kind_of(String), { replace: true }]
      chat_mock.expect :with_tool, chat_mock, [request_detector_mock]
      chat_mock.expect :on_tool_call, chat_mock
      chat_mock.expect :on_tool_result, chat_mock
      chat_mock.expect :with_tool_params, chat_mock, [request_detector_mock, kind_of(Hash)]
      chat_mock.expect :ask, Minitest::Mock.new, ['Записаться на диагностику']

      RubyLLM.stub(:chat, chat_mock) do
        response = @client.send_message([{ role: 'user', content: 'Записаться на диагностику' }], user_info)
        assert response.is_a?(String)
      end
    end

    @logger.verify
  end

  def test_conversation_context_preparation
    @logger.expect :info, nil, ['Sending message to RubyLLM with 3 messages']
    @logger.expect :info, nil, ['LLMClient model: gpt-3.5-turbo, provider: openai (configured as: openai)']
    @logger.expect :debug, nil, ['Last message content: Final message...']
    @logger.expect :info, nil, ['🔔 REQUEST DETECTED: AI calling tool: request_detector for user 777']
    @logger.expect :debug, nil, [/Tool arguments: \{.*\}/]
    @logger.expect :info, nil, ['✅ REQUEST SENT: service for user 777']
    @logger.expect :debug, nil, ['Sending message to RubyLLM API...']
    @logger.expect :debug, nil, ['Received response from RubyLLM API']

    user_info = { id: 777, username: 'context_user' }

    messages = [
      { role: 'user', content: 'My car makes strange noise' },
      { role: 'assistant', content: 'What kind of noise?' },
      { role: 'user', content: 'It is a grinding noise when braking' }
    ]

    chat_mock = Minitest::Mock.new
    chat_mock.expect :with_instructions, chat_mock, [kind_of(String), { replace: true }]
    chat_mock.expect :with_tool, chat_mock, [kind_of(RequestDetector)]
    chat_mock.expect :on_tool_call, chat_mock
    chat_mock.expect :on_tool_result, chat_mock

    # Verify that conversation context is passed correctly
    expected_context = "user: My car makes strange noise\nassistant: What kind of noise?\nuser: It is a grinding noise when braking"

    chat_mock.expect :with_tool_params, chat_mock do |detector, params|
      params[:conversation_context] == expected_context
    end

    chat_mock.expect :ask, Minitest::Mock.new, ['Final message']

    RubyLLM.stub(:chat, chat_mock) do
      response = @client.send_message(messages, user_info)
      assert response.is_a?(String)
    end

    @logger.verify
  end

  def teardown
    @config.verify if @config.respond_to?(:verify)
  end
end