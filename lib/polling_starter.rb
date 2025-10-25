# frozen_string_literal: true

require 'logger'

class PollingStarter
  def initialize(telegram_bot_handler)
    @telegram_bot_handler = telegram_bot_handler
  end

  def start
    Application.instance.logger.info 'Polling mode started'
    Application.instance.logger.info 'Listening for updates from Telegram...'
    @telegram_bot_handler.handle_polling
  end
end
