# frozen_string_literal: true

require_relative 'test_helper'

class TestRubyLLMClientIntegration < Minitest::Test
  def setup
    # Use fixture files
    @system_prompt_path = File.expand_path('fixtures/system-prompt.md', __dir__)
    @price_list_path = File.expand_path('fixtures/кузник.csv', __dir__)

    # Create a test config using fixture files
    @config = OpenStruct.new(
      anthropic_model: 'claude-3-5-sonnet-20241022',
      anthropic_auth_token: 'test_token',
      anthropic_base_url: 'https://api.anthropic.com',
      system_prompt_path: @system_prompt_path,
      price_list_path: @price_list_path,
      ruby_llm_model: nil,
      debug_api_requests: false,
      llm_provider: 'anthropic',
      llm_model: 'claude-3-5-sonnet-20241022',
      openai_api_key: 'test_openai_api_key_12345',
      anthropic_api_key: 'test_anthropic_api_key_12345'
    )

    @logger = NullLogger.new
  end

  def test_initialization_loads_system_prompt
    client = RubyLLMClient.new(@config, @logger)
    system_prompt = client.instance_variable_get(:@system_prompt)
    assert_equal File.read(@system_prompt_path), system_prompt
  end

  def test_initialization_loads_price_list
    client = RubyLLMClient.new(@config, @logger)
    price_list = client.instance_variable_get(:@price_list)
    assert_includes price_list, 'АКТУАЛЬНЫЙ ПРАЙС-ЛИСТ'
    assert_includes price_list, 'Диагностика двигателя'
  end

  def test_send_message_with_real_api_error_handling
    # Test with invalid token to see error handling
    config = OpenStruct.new(
      anthropic_model: 'claude-3-5-sonnet-20241022',
      anthropic_auth_token: 'invalid_token',
      anthropic_base_url: 'https://api.anthropic.com',
      system_prompt_path: @system_prompt_path,
      price_list_path: @price_list_path,
      ruby_llm_model: nil,
      debug_api_requests: false,
      llm_provider: 'anthropic',
      llm_model: 'claude-3-5-sonnet-20241022',
      openai_api_key: 'test_openai_api_key_12345',
      anthropic_api_key: 'test_anthropic_api_key_12345'
    )

    client = RubyLLMClient.new(config, @logger)

    # This should fail with authentication error, but not crash
    assert_raises(StandardError) do
      client.send_message([{ role: 'user', content: 'Hello' }])
    end
  end

  def test_error_handling_classes_exist
    # Test that the error handling classes we use exist
    assert defined?(RubyLLM::ConfigurationError)
    assert defined?(RubyLLM::ModelNotFoundError)
    assert defined?(RubyLLM::Error)
  end

  def test_configuration_with_ruby_llm_model
    # Test with explicit ruby_llm_model set
    config = OpenStruct.new(
      anthropic_model: 'claude-3-5-sonnet-20241022',
      anthropic_auth_token: 'test_token',
      anthropic_base_url: 'https://api.anthropic.com',
      system_prompt_path: @system_prompt_path,
      price_list_path: @price_list_path,
      ruby_llm_model: 'claude-3-5-sonnet-20241022',
      debug_api_requests: false,
      llm_provider: 'anthropic',
      llm_model: 'claude-3-5-sonnet-20241022',
      openai_api_key: 'test_openai_api_key_12345',
      anthropic_api_key: 'test_anthropic_api_key_12345'
    )

    client = RubyLLMClient.new(config, @logger)

    # Client should be created successfully
    assert_kind_of RubyLLMClient, client
  end

  def test_send_message_with_invalid_role
    # Test error handling for invalid message role
    client = RubyLLMClient.new(@config, @logger)

    # Test with invalid role (assistant instead of user)
    assert_raises(ArgumentError) do
      client.send_message([{ role: 'assistant', content: 'Hello' }])
    end

    # Test with empty messages
    assert_raises(ArgumentError) do
      client.send_message([])
    end
  end

  def test_price_list_formatting
    client = RubyLLMClient.new(@config, @logger)
    price_list = client.instance_variable_get(:@price_list)

    # Check that the price list is properly formatted
    assert_includes price_list, '📋 АКТУАЛЬНЫЙ ПРАЙС-ЛИСТ'
    assert_includes price_list, '📋 Услуга,Цена'
    assert_includes price_list, '📋 Диагностика двигателя,1500'
    assert_includes price_list, '⚠️ ВАЖНОЕ ПРИМЕЧАНИЕ:'
    assert_includes price_list, '─' * 50
  end
end
