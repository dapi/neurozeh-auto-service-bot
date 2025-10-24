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

RubyLLM.configure do |config|
  # Используем OpenAI API ключ
  # Устанавливаем таймауты и retry настройки
  config.request_timeout = 120 # AppConfig.request_timeout
  config.max_retries = 1 # AppConfig.max_retries
  config.openai_api_key = ENV.fetch('OPENAI_API_KEY', nil)
  config.anthropic_api_key = ENV.fetch('ANTHROPIC_API_KEY', nil)
  config.gemini_api_key = ENV.fetch('GEMINI_API_KEY', nil)
  config.deepseek_api_key = ENV.fetch('DEEPSEEK_API_KEY', nil)
  config.perplexity_api_key = ENV.fetch('PERPLEXITY_API_KEY', nil)
  config.openrouter_api_key = ENV.fetch('OPENROUTER_API_KEY', nil)
  config.mistral_api_key = ENV.fetch('MISTRAL_API_KEY', nil)
  config.vertexai_location = ENV.fetch('GOOGLE_CLOUD_LOCATION', nil)
  config.vertexai_project_id = ENV.fetch('GOOGLE_CLOUD_PROJECT', nil)
end
