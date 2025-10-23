require 'anyway_config'

class AppConfig < Anyway::Config
  config_name :kuznik_bot
  env_prefix ''

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
    log_level: 'info',

    # Bot mode configuration (polling or webhook)
    bot_mode: 'polling',

    # Webhook configuration
    webhook_url: '',
    webhook_port: 3000,
    webhook_host: '0.0.0.0',
    webhook_path: '/telegram/webhook'
  )

  # Declare required parameters using anyway_config's required method
  required :anthropic_auth_token, :telegram_bot_token

  # Custom validation for system prompt file and bot configuration
  def initialize
    super

    raise 'System prompt file not found' unless File.exist?(system_prompt_path)

    # Validate bot mode
    unless %w[polling webhook].include?(bot_mode)
      raise "BOT_MODE must be 'polling' or 'webhook', got: #{bot_mode}"
    end

    # Validate webhook URL for webhook mode
    if bot_mode == 'webhook' && webhook_url.to_s.empty?
      raise 'WEBHOOK_URL is required when BOT_MODE is webhook'
    end
  end
end
