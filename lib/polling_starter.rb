# frozen_string_literal: true

require 'logger'

class PollingStarter
  def initialize(config, logger, telegram_bot_handler)
    @config = config
    @logger = logger
    @telegram_bot_handler = telegram_bot_handler
  end

  def start
    @logger.info 'Polling mode started'
    @logger.info 'Listening for updates from Telegram...'
    @telegram_bot_handler.handle_polling
  end
end
