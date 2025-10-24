require_relative 'initializers/ruby_llm'
# Load components
require_relative '../lib/rate_limiter'
require_relative '../lib/conversation_manager'
require_relative '../lib/llm_client'
require_relative '../lib/telegram_bot_handler'
require_relative '../lib/bot_launcher'
require_relative '../lib/polling_starter'
require_relative '../lib/webhook_starter'

# Load application code
# $LOAD_PATH.unshift File.expand_path('../lib', __dir__)
# $LOAD_PATH.unshift File.expand_path('../config', __dir__)
