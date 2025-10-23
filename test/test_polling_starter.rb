require_relative 'test_helper'
require_relative '../lib/polling_starter'

class TestPollingStarter < Minitest::Test
  def setup
    @config = Minitest::Mock.new
    @logger = NullLogger.new
    @telegram_bot_handler = Minitest::Mock.new
  end

  def test_polling_starter_calls_handle_polling
    @telegram_bot_handler.expect(:handle_polling, nil)

    starter = PollingStarter.new(@config, @logger, @telegram_bot_handler)
    starter.start

    @telegram_bot_handler.verify
  end

  def test_polling_starter_initializes_correctly
    starter = PollingStarter.new(@config, @logger, @telegram_bot_handler)

    assert_equal @config, starter.instance_variable_get(:@config)
    assert_equal @logger, starter.instance_variable_get(:@logger)
    assert_equal @telegram_bot_handler, starter.instance_variable_get(:@telegram_bot_handler)
  end
end
