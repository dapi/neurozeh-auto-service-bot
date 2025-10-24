# frozen_string_literal: true

require 'minitest/autorun'
require 'minitest/mock'
require 'logger'
require 'webmock'
require 'ostruct'

# Load application code
$LOAD_PATH.unshift File.expand_path('../lib', __dir__)
$LOAD_PATH.unshift File.expand_path('../config', __dir__)

require_relative '../lib/rate_limiter'
require_relative '../lib/conversation_manager'
require_relative '../lib/ruby_llm_client'
require_relative '../lib/telegram_bot_handler'
require_relative '../config/app_config'

# Suppress logs during tests
class NullLogger < Logger
  def initialize
    super(IO::NULL)
  end
end
