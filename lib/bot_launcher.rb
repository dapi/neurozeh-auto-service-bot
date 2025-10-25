# frozen_string_literal: true

require 'logger'

class BotLauncher
  def initialize(telegram_bot_handler)
    @telegram_bot_handler = telegram_bot_handler
  end

  def start
    Application.instance.logger.info "Bot starting in #{AppConfig.bot_mode} mode..."

    case AppConfig.bot_mode
    when 'polling'
      start_polling_mode
    when 'webhook'
      start_webhook_mode
    else
      raise "Unknown bot mode: #{AppConfig.bot_mode}"
    end
  end

  private

  def start_polling_mode
    starter = PollingStarter.new(@telegram_bot_handler)
    starter.start
  end

  def start_webhook_mode
    starter = WebhookStarter.new(@telegram_bot_handler)
    starter.start
  end
end
