# frozen_string_literal: true

require File.expand_path('../config/application', __dir__)
require 'minitest/autorun'
require 'minitest/mock'
require 'webmock'

# Suppress logs during tests
class NullLogger < Logger
  def initialize
    super(IO::NULL)
  end
end
