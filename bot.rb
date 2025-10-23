#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'config/boot'

# Initialize logger
log_level = ENV['LOG_LEVEL']&.upcase || 'INFO'
logger = Logger.new($stdout)
logger.level = Logger.const_get(log_level)

# Load configuration
config = AppConfig.new

logger.info 'Kuznik Bot starting...'
logger.info 'Configuration loaded:'
logger.info "  - Model: #{config.anthropic_model}"
logger.info "  - API Base URL: #{config.anthropic_base_url}"
logger.info "  - Rate Limit: #{config.rate_limit_requests} requests per #{config.rate_limit_period} seconds"
logger.info "  - Max History Size: #{config.max_history_size}"

# Initialize components
rate_limiter = RateLimiter.new(
  config.rate_limit_requests,
  config.rate_limit_period
)
logger.info 'RateLimiter initialized'

conversation_manager = ConversationManager.new(config.max_history_size)
logger.info 'ConversationManager initialized'

claude_client = ClaudeClient.new(config, logger)
logger.info 'ClaudeClient initialized'

telegram_bot_handler = TelegramBotHandler.new(
  config,
  claude_client,
  rate_limiter,
  conversation_manager,
  logger
)
logger.info 'TelegramBotHandler initialized'

# Launch bot with appropriate mode
launcher = BotLauncher.new(config, logger, telegram_bot_handler)
logger.info "BotLauncher initialized for mode: #{config.bot_mode}"

# Handle signals
trap('INT') do
  logger.info 'Received SIGINT, shutting down...'
  exit(0)
end

# Start the bot
logger.info 'Starting bot...'
launcher.start
