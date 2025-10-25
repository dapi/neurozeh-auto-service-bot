require_relative 'boot'

class Application
  def initialize
    puts "DEBUG: Starting Application initialize"

    puts "DEBUG: About to call telegram_bot_handler"
    telegram_bot_handler
    puts "DEBUG: telegram_bot_handler completed"

    # Setup signal handling after initialization
    setup_signal_handlers
    puts "DEBUG: Application initialize completed"
  end

  def setup_signal_handlers
    trap('INT') do
      puts 'Received SIGINT, shutting down...'
      exit(0)
    end
  rescue => e
    # Fallback if trap setup fails
    warn "Could not setup signal handlers: #{e.message}"
  end

  def config
    AppConfig
  end

  def root
    File.expand_path('..', __dir__).freeze
  end

  def rate_limiter
    @rate_limiter ||= RateLimiter.new(
      AppConfig.rate_limit_requests,
      AppConfig.rate_limit_period
    )
  end

  def telegram_bot_handler
    @telegram_bot_handler ||= TelegramBotHandler.new(
      ai_client,
      rate_limiter,
      conversation_manager,
      logger
    )
  end

  def ai_client
    @ai_client ||= LLMClient.new(conversation_manager, logger)
  end

  def conversation_manager
    @conversation_manager ||= ConversationManager.new
  end

  def logger
    @logger ||= build_logger
  end

  def log_level
    ENV['LOG_LEVEL']&.upcase || 'INFO'
  end

  private

  def build_logger
    # Initialize logger - use ::Logger to avoid namespace conflicts
    instance_logger = ::Logger.new($stdout)
    instance_logger.level = ::Logger.const_get(log_level)
    instance_logger
  end

  class << self
    def initialize!
      instance
    end

    # Returns a singleton config instance
    def instance
      @instance ||= new
    end
  end
end
