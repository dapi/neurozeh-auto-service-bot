require 'bundler/setup'
require 'logger'
require 'debug'

# Load configuration
require_relative 'app_config'

# Load components
require_relative '../lib/rate_limiter'
require_relative '../lib/conversation_manager'
require_relative '../lib/claude_client'
require_relative '../lib/ruby_llm_client'
require_relative '../lib/telegram_bot_handler'
require_relative '../lib/bot_launcher'
require_relative '../lib/polling_starter'
require_relative '../lib/webhook_starter'
