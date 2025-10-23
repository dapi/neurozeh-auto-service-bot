require 'anyway_config'

class AppConfig < Anyway::Config
  config_name :kuznik_bot

  # Claude API configuration
  attr_config(
    anthropic_base_url: 'https://api.z.ai/api/anthropic',
    anthropic_auth_token: '',
    anthropic_model: 'glm-4.5-air',
    system_prompt_path: './system-prompt.md',

    # Telegram configuration
    telegram_bot_token: '',

    # Rate limiter configuration
    rate_limit_requests: 10,
    rate_limit_period: 60,

    # Conversation management
    max_history_size: 10,

    # Logging
    log_level: 'info'
  )

  def validate!
    raise 'ANTHROPIC_AUTH_TOKEN is required' if anthropic_auth_token.to_s.empty?
    raise 'TELEGRAM_BOT_TOKEN is required' if telegram_bot_token.to_s.empty?
    raise 'System prompt file not found' unless File.exist?(system_prompt_path)
  end
end
