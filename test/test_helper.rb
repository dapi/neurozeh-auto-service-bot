# frozen_string_literal: true

require File.expand_path('../config/environment', __dir__)
require 'minitest/autorun'
require 'minitest/mock'
require 'webmock'

# Suppress logs during tests
class NullLogger < Logger
  def initialize
    super(IO::NULL)
  end
end

# Clean up database between tests
module DatabaseCleaner
  def self.clean
    Message.destroy_all
    Chat.destroy_all
  end
end

class Minitest::Test
  def setup
    DatabaseCleaner.clean
    super
  end
end
