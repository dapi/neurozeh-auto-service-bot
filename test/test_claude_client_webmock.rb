# frozen_string_literal: true

require_relative 'test_helper'

class TestClaudeClientWebmock < Minitest::Test
  def setup
    # Enable WebMock
    WebMock.enable!

    # Use fixture files
    @system_prompt_path = File.expand_path('fixtures/system-prompt.md', __dir__)
    @price_list_path = File.expand_path('fixtures/кузник.csv', __dir__)

    # Create a test config using fixture files
    @config = Minitest::Mock.new
    @config.expect(:anthropic_model, 'glm-4.5-air')
    @config.expect(:anthropic_auth_token, 'test_token')
    @config.expect(:anthropic_base_url, 'https://api.anthropic.com/v1/messages')
    @config.expect(:system_prompt_path, @system_prompt_path)
    @config.expect(:price_list_path, @price_list_path)
    @config.expect(:debug_api_requests, false)

    @logger = NullLogger.new
  end

  def teardown
    WebMock.disable!
    WebMock.reset!
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

  def test_send_message_with_webmock_success
    # Add additional expectations for config access in send_message
    @config.expect(:debug_api_requests, false)
    @config.expect(:anthropic_auth_token, 'test_token')
    @config.expect(:anthropic_model, 'glm-4.5-air')
    @config.expect(:anthropic_base_url, 'https://api.anthropic.com/v1/messages')

    # Mock the HTTP request with WebMock using config URL
    WebMock.stub_request(:post, @config.anthropic_base_url)
      .with(
        headers: {
          'Authorization' => 'Bearer test_token',
          'Content-Type' => 'application/json'
        },
        body: lambda { |request_body|
          json_body = JSON.parse(request_body)
          json_body['model'] == 'glm-4.5-air' &&
          json_body['max_tokens'] == 1500 &&
          json_body['messages'] == [{ 'role' => 'user', 'content' => 'Hello' }]
        }
      )
      .to_return(
        status: 200,
        body: JSON.generate({ 'content' => [{ 'text' => 'Test response' }] }),
        headers: { 'Content-Type' => 'application/json' }
      )

    client = ClaudeClient.new(@config, @logger)
    response = client.send_message([{ role: 'user', content: 'Hello' }])
    assert_equal 'Test response', response
  end

  def test_send_message_with_webmock_error
    # Add additional expectations for config access in send_message
    @config.expect(:debug_api_requests, false)
    @config.expect(:anthropic_auth_token, 'test_token')
    @config.expect(:anthropic_model, 'glm-4.5-air')
    @config.expect(:anthropic_base_url, 'https://api.anthropic.com/v1/messages')
    @config.expect(:debug_api_requests, false) # For error handling

    # Mock the HTTP request to return an error using config URL
    WebMock.stub_request(:post, @config.anthropic_base_url)
      .to_return(
        status: 500,
        body: JSON.generate({ 'error' => { 'message' => 'Internal server error' } }),
        headers: { 'Content-Type' => 'application/json' }
      )

    client = ClaudeClient.new(@config, @logger)

    assert_raises(RuntimeError) do
      client.send_message([{ role: 'user', content: 'Hello' }])
    end
  end

  def test_debug_logging_enabled
    # Test with debug enabled
    @config.expect(:debug_api_requests, true)
    @config.expect(:anthropic_base_url, 'https://api.anthropic.com/v1/messages')

    # Mock successful request using config URL
    WebMock.stub_request(:post, @config.anthropic_base_url)
      .to_return(
        status: 200,
        body: JSON.generate({ 'content' => [{ 'text' => 'Debug response' }] }),
        headers: { 'Content-Type' => 'application/json' }
      )

    client = ClaudeClient.new(@config, @logger)
    connection = client.instance_variable_get(:@connection)

    # Connection should be created successfully with debug logging
    assert_kind_of Faraday::Connection, connection
  end
end