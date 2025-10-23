require_relative 'test_helper'

class TestAppConfig < Minitest::Test
  def setup
    # Create test system prompt file
    File.write('./system-prompt.md', 'Test prompt') unless File.exist?('./system-prompt.md')

    # Set up base env vars
    ENV['ANTHROPIC_AUTH_TOKEN'] = 'test_token'
    ENV['TELEGRAM_BOT_TOKEN'] = 'test_bot_token'
    ENV['SYSTEM_PROMPT_PATH'] = './system-prompt.md'
  end

  def teardown
    File.delete('./system-prompt.md') if File.exist?('./system-prompt.md')
  end

  def test_config_can_be_initialized
    config = AppConfig.new
    assert_instance_of AppConfig, config
  end
end
