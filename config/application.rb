require_relative 'boot'

class Application
  def initialize
    # Handle signals
    trap('INT') do
      logger.info 'Received SIGINT, shutting down...'
      exit(0)
    end

    logger.info 'Auto Service Bot starting...'
    logger.info 'Configuration loaded:'
    logger.info "  - Model: #{config.llm_model}"
    logger.info "  - OpenAI API Base URL: #{config.openai_api_base || 'default'}"
    logger.info "  - Provider: #{config.llm_provider}"
    logger.info "  - Model: #{config.llm_model}"
    logger.info "  - Rate Limit: #{config.rate_limit_requests} requests per #{config.rate_limit_period} seconds"
    logger.info "  - Max History Size: #{config.max_history_size}"
    telegram_bot_handler # INitialize
    logger.info 'Telegram Bot Handler Initialized'
  end

  def config
    AppConfig
  end

  def root
    File.expand_path('..', __dir__).freeze
  end

  def rate_limiter
    @rate_limiter ||= RateLimiter.new(
      config.rate_limit_requests,
      config.rate_limit_period
    )
  end

  def telegram_bot_handler
    @telegram_bot_handler ||= TelegramBotHandler.new(
      config,
      ai_client,
      rate_limiter,
      conversation_manager,
      logger
    )
  end

  def ai_client
    @ai_client ||= LLMClient.new(config, logger)
  end

  def conversation_manager
    @conversation_manager ||= ConversationManager.new(config.max_history_size)
  end

  def logger
    @logger ||= build_logger
  end

  def log_level
    ENV['LOG_LEVEL']&.upcase || 'INFO'
  end

  private

  def build_logger
    # Initialize logger
    logger = Logger.new($stdout)
    logger.level = Logger.const_get(log_level)
    logger
  end

  class << self
    # Make it possible to access a singleton config instance
    # via class methods (i.e., without explicitly calling `instance`)
    delegate_missing_to :instance

    def initialize!
      instance
    end

    private

    # Returns a singleton config instance
    def instance
      @instance ||= new
    end
  end
end
