require_relative 'test_helper'

class TestAppConfig < Minitest::Test
  def setup
    # Create test system prompt file
    File.write('./system-prompt.md', 'Test prompt') unless File.exist?('./system-prompt.md')

    # Set up base env vars - required by anyway_config
    ENV['ANTHROPIC_AUTH_TOKEN'] = 'test_token'
    ENV['TELEGRAM_BOT_TOKEN'] = 'test_bot_token'
    ENV['SYSTEM_PROMPT_PATH'] = './system-prompt.md'
  end

  def teardown
    File.delete('./system-prompt.md') if File.exist?('./system-prompt.md')
  end

  def test_config_validates_required_anthropic_token
    # Remove required env var before creating new config
    saved_val = ENV['ANTHROPIC_AUTH_TOKEN']
    ENV['ANTHROPIC_AUTH_TOKEN'] = ''

    # Suppress stderr to avoid polluting test output with validation error message
    stderr_backup = $stderr
    $stderr = StringIO.new

    begin
      assert_raises(Anyway::Config::ValidationError) do
        AppConfig.new
      end
    ensure
      ENV['ANTHROPIC_AUTH_TOKEN'] = saved_val
      $stderr = stderr_backup
    end
  end

  def test_config_validates_required_telegram_token
    # Remove required env var before creating new config
    saved_val = ENV['TELEGRAM_BOT_TOKEN']
    ENV['TELEGRAM_BOT_TOKEN'] = ''

    # Suppress stderr to avoid polluting test output with validation error message
    stderr_backup = $stderr
    $stderr = StringIO.new

    begin
      assert_raises(Anyway::Config::ValidationError) do
        AppConfig.new
      end
    ensure
      ENV['TELEGRAM_BOT_TOKEN'] = saved_val
      $stderr = stderr_backup
    end
  end

end
