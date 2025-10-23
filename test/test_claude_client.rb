# frozen_string_literal: true

require_relative 'test_helper'

class TestClaudeClient < Minitest::Test
  def setup
    # Create a test config
    @config = Minitest::Mock.new
    @config.expect(:anthropic_model, 'glm-4.5-air')
    @config.expect(:anthropic_auth_token, 'test_token')
    @config.expect(:anthropic_base_url, 'https://api.z.ai/api/anthropic')
    @config.expect(:system_prompt_path, './system-prompt.md')

    # Create test system prompt file
    File.write('./system-prompt.md', 'Test system prompt')

    @logger = NullLogger.new
  end

  def teardown
    File.delete('./system-prompt.md') if File.exist?('./system-prompt.md')
  end

  def test_initialization_loads_system_prompt
    client = ClaudeClient.new(@config, @logger)
    assert_equal 'Test system prompt', client.instance_variable_get(:@system_prompt)
  end

  def test_send_message_with_valid_response
    client = ClaudeClient.new(@config, @logger)

    mock_response = Minitest::Mock.new
    mock_response.expect(:success?, true)
    mock_response.expect(:body, '{"content":[{"text":"Test response"}]}')

    ClaudeClient.stub(:post, mock_response) do
      response = client.send_message([{ role: 'user', content: 'Hello' }])
      assert_equal 'Test response', response
    end
  end

  def test_send_message_error_handling
    client = ClaudeClient.new(@config, @logger)

    ClaudeClient.stub(:post, -> { raise StandardError, 'API Error' }) do
      assert_raises(StandardError) do
        client.send_message([{ role: 'user', content: 'Hello' }])
      end
    end
  end

  def test_parse_response_extracts_text
    client = ClaudeClient.new(@config, @logger)

    # Create a proper mock response object
    mock_response = Object.new
    def mock_response.success? = true
    def mock_response.body = '{"content":[{"text":"Hello from Claude"}]}'

    # Test through public method using stub
    ClaudeClient.stub(:post, mock_response) do
      response = client.send_message([{ role: 'user', content: 'Hi' }])
      assert_equal 'Hello from Claude', response
    end
  end
end
