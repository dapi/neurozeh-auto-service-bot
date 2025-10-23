# frozen_string_literal: true

require_relative 'test_helper'

class TestClaudeClientWebmock < Minitest::Test
  def setup
    # Use fixture files
    @system_prompt_path = File.expand_path('fixtures/system-prompt.md', __dir__)
    @price_list_path = File.expand_path('fixtures/кузник.csv', __dir__)

    # Create a test config using fixture files
    @config = Minitest::Mock.new
    @config.expect(:anthropic_model, 'glm-4.5-air')
    @config.expect(:anthropic_auth_token, 'test_token')
    @config.expect(:anthropic_base_url, 'https://api.anthropic.com')
    @config.expect(:system_prompt_path, @system_prompt_path)
    @config.expect(:price_list_path, @price_list_path)
    @config.expect(:debug_api_requests, false)

    @logger = NullLogger.new
  end

  def test_initialization_loads_system_prompt
    client = ClaudeClient.new(@config, @logger)
    assert_equal File.read(@system_prompt_path), client.instance_variable_get(:@system_prompt)
  end

  def test_initialization_loads_price_list
    client = ClaudeClient.new(@config, @logger)
    price_list = client.instance_variable_get(:@price_list)
    assert_includes price_list, "АКТУАЛЬНЫЙ ПРАЙС-ЛИСТ"
    assert_includes price_list, "Диагностика двигателя"
  end

  def test_send_message_with_mock_success
    # Add additional expectations for config access in send_message
    @config.expect(:debug_api_requests, false)
    @config.expect(:anthropic_auth_token, 'test_token')
    @config.expect(:anthropic_model, 'glm-4.5-air')
    @config.expect(:anthropic_base_url, 'https://api.anthropic.com')

    # Create a mock Anthropic client response
    mock_text_block = Minitest::Mock.new
    mock_text_block.expect(:text, 'Test response')
    mock_text_block.expect(:is_a?, true, [Anthropic::Models::TextBlock])

    mock_response = Minitest::Mock.new
    mock_response.expect(:content, [mock_text_block])

    # Mock the Anthropic client
    mock_anthropic_client = Minitest::Mock.new
    mock_messages = Minitest::Mock.new

    # Use a custom matcher for the system parameter
    create_params = nil
    mock_messages.expect(:create, mock_response) do |params|
      create_params = params
      params[:model] == 'glm-4.5-air' &&
      params[:max_tokens] == 1500 &&
      params[:messages] == [{ role: 'user', content: 'Hello' }] &&
      params[:system].is_a?(String)
    end

    mock_anthropic_client.expect(:messages, mock_messages)

    client = ClaudeClient.new(@config, @logger)

    # Replace the internal client with our mock
    client.instance_variable_set(:@client, mock_anthropic_client)

    response = client.send_message([{ role: 'user', content: 'Hello' }])
    assert_equal 'Test response', response

    # Verify the system parameter was set correctly
    assert_kind_of String, create_params[:system]
    assert_includes create_params[:system], "ПРАЙС-ЛИСТ"

    # Verify all mocks were called
    mock_text_block.verify
    mock_response.verify
    mock_messages.verify
    mock_anthropic_client.verify
  end

  def test_error_handling_classes_exist
    # Test that the error handling classes we use exist
    assert defined?(Anthropic::Errors::AuthenticationError)
    assert defined?(Anthropic::Errors::RateLimitError)
    assert defined?(Anthropic::Errors::APIError)
  end

  def test_debug_logging_enabled
    # Test with debug enabled
    @config.expect(:debug_api_requests, true)
    @config.expect(:anthropic_auth_token, 'test_token')
    @config.expect(:anthropic_base_url, 'https://api.anthropic.com')

    client = ClaudeClient.new(@config, @logger)
    anthropic_client = client.instance_variable_get(:@client)

    # Anthropic client should be created successfully
    assert_kind_of Anthropic::Client, anthropic_client
  end
end