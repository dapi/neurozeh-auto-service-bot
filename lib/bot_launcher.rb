# frozen_string_literal: true

require 'logger'

class BotLauncher
  def initialize(config, logger, telegram_bot_handler)
    @config = config
    @logger = logger
    @telegram_bot_handler = telegram_bot_handler
  end

  def start
    @logger.info "Bot starting in #{@config.bot_mode} mode..."

    case @config.bot_mode
    when 'polling'
      start_polling_mode
    when 'webhook'
      start_webhook_mode
    else
      raise "Unknown bot mode: #{@config.bot_mode}"
    end
  end

  private

  def start_polling_mode
    starter = PollingStarter.new(@config, @logger, @telegram_bot_handler)
    starter.start
  end

  def start_webhook_mode
    starter = WebhookStarter.new(@config, @logger, @telegram_bot_handler)
    starter.start
  end
end
