# frozen_string_literal: true

require 'ruby_llm'


# Configure RubyLLM with API keys from environment variables
RubyLLM.configure do |config|
  # For DeepSeek using z.ai endpoint (OpenAI-compatible)
  if ENV['LLM_PROVIDER'] == 'deepseek'
    config.openai_api_key = ENV['DEEPSEEK_API_KEY']
    config.openai_api_base = ENV['OPENAI_API_BASE'] if ENV['OPENAI_API_BASE']
  end

  # OpenAI configuration (if needed)
  config.openai_api_key = ENV['OPENAI_API_KEY'] if ENV['OPENAI_API_KEY']

  # Anthropic configuration (if needed)
  config.anthropic_api_key = ENV['ANTHROPIC_API_KEY'] if ENV['ANTHROPIC_API_KEY']

  # Enable debug logging if requested
  config.log_level = :debug if ENV['RUBYLLM_DEBUG'] == 'true'
  config.log_stream_debug = true if ENV['RUBYLLM_STREAM_DEBUG'] == 'true'
end