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
    webhook_path: '/telegram/webhook',

    # Price list configuration
    price_list_path: './data/кузник.csv'
  )

  # Declare required parameters using anyway_config's required method
  required :anthropic_auth_token, :telegram_bot_token

  # Валидация с использованием on_load callbacks вместо manual checks in initialize
  on_load :validate_system_prompt_file
  on_load :validate_price_list_file
  on_load :validate_bot_mode
  on_load :validate_webhook_requirements
  on_load :validate_numeric_parameters

  private

  def validate_system_prompt_file
    path = system_prompt_path
    raise ArgumentError, "System prompt file not found: #{path}" unless File.exist?(path)
    raise ArgumentError, "System prompt file not readable: #{path}" unless File.readable?(path)
  end

  def validate_price_list_file
    path = price_list_path
    raise ArgumentError, "Price list file not found: #{path}" unless File.exist?(path)
    raise ArgumentError, "Price list file not readable: #{path}" unless File.readable?(path)

    # Дополнительная валидация формата CSV
    unless path.end_with?('.csv')
      raise ArgumentError, "Price list file must be a CSV file: #{path}"
    end
  end

  def validate_bot_mode
    unless %w[polling webhook].include?(bot_mode)
      raise ArgumentError, "BOT_MODE must be 'polling' or 'webhook', got: #{bot_mode}"
    end
  end

  def validate_webhook_requirements
    if bot_mode == 'webhook' && webhook_url.to_s.empty?
      raise ArgumentError, 'WEBHOOK_URL is required when BOT_MODE is webhook'
    end
  end

  def validate_numeric_parameters
    unless rate_limit_requests.is_a?(Integer) && rate_limit_requests > 0
      raise ArgumentError, "RATE_LIMIT_REQUESTS must be a positive integer"
    end

    unless rate_limit_period.is_a?(Integer) && rate_limit_period > 0
      raise ArgumentError, "RATE_LIMIT_PERIOD must be a positive integer"
    end

    unless max_history_size.is_a?(Integer) && max_history_size > 0
      raise ArgumentError, "MAX_HISTORY_SIZE must be a positive integer"
    end
  end
end
