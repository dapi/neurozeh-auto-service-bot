# frozen_string_literal: true

require 'anyway_config'

class AppConfig < Anyway::Config
  config_name :auto_service_bot
  env_prefix ''

  # Claude API configuration (legacy for backward compatibility)
  attr_config(
    # RubyLLM configuration
    llm_provider: 'openai',
    llm_model: 'glm-4.5-air', # Используем z.ai
    openai_api_base: nil, # Опциональный OpenAI-совместимый API endpoint (например, https://api.z.ai/v1)

    # File paths
    system_prompt_path: './config/system-prompt.md',
    welcome_message_path: './config/welcome-message.md',
    price_list_path: './config/price.csv',
    company_info_path: './config/company-info.md',

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

  # Type coercions to ensure proper data types from environment variables
  coerce_types(
    # Strings
    llm_provider: :string,
    llm_model: :string,
    openai_api_base: :string,
    system_prompt_path: :string,
    welcome_message_path: :string,
    price_list_path: :string,
    company_info_path: :string,
    telegram_bot_token: :string,
    log_level: :string,
    bot_mode: :string,
    webhook_url: :string,
    webhook_host: :string,
    webhook_path: :string,

    # Integers
    rate_limit_requests: :integer,
    rate_limit_period: :integer,
    max_history_size: :integer,
    webhook_port: :integer
  )

  # Declare required parameters using anyway_config's required method
  required :telegram_bot_token, :llm_provider, :llm_model

  # Валидация с использованием on_load callbacks вместо manual checks в initialize
  on_load :validate_system_prompt_file
  on_load :validate_welcome_message_file
  on_load :validate_price_list_file
  on_load :validate_company_info_file
  on_load :validate_bot_mode
  on_load :validate_webhook_requirements
  on_load :validate_numeric_parameters

  private

  def validate_system_prompt_file
    path = system_prompt_path
    raise ArgumentError, "System prompt file not found: #{path}" unless File.exist?(path)
    raise ArgumentError, "System prompt file not readable: #{path}" unless File.readable?(path)
  end

  def validate_welcome_message_file
    path = welcome_message_path
    raise ArgumentError, "Welcome message file not found: #{path}" unless File.exist?(path)
    raise ArgumentError, "Welcome message file not readable: #{path}" unless File.readable?(path)
  end

  def validate_price_list_file
    path = price_list_path
    raise ArgumentError, "Price list file not found: #{path}" unless File.exist?(path)
    raise ArgumentError, "Price list file not readable: #{path}" unless File.readable?(path)

    # Дополнительная валидация формата CSV
    return if path.end_with?('.csv')

    raise ArgumentError, "Price list file must be a CSV file: #{path}"
  end

  def validate_company_info_file
    path = company_info_path
    raise ArgumentError, "Company info file not found: #{path}" unless File.exist?(path)
    raise ArgumentError, "Company info file not readable: #{path}" unless File.readable?(path)
  end

  def validate_bot_mode
    return if %w[polling webhook].include?(bot_mode)

    raise ArgumentError, "BOT_MODE must be 'polling' or 'webhook', got: #{bot_mode}"
  end

  def validate_webhook_requirements
    return unless bot_mode == 'webhook' && webhook_url.to_s.empty?

    raise ArgumentError, 'WEBHOOK_URL is required when BOT_MODE is webhook'
  end

  def validate_numeric_parameters
    unless rate_limit_requests.is_a?(Integer) && rate_limit_requests.positive?
      raise ArgumentError, 'RATE_LIMIT_REQUESTS must be a positive integer'
    end

    unless rate_limit_period.is_a?(Integer) && rate_limit_period.positive?
      raise ArgumentError, 'RATE_LIMIT_PERIOD must be a positive integer'
    end

    return if max_history_size.is_a?(Integer) && max_history_size.positive?

    raise ArgumentError, 'MAX_HISTORY_SIZE must be a positive integer'
  end
end
