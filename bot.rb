#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'config/environment'

# Launch bot with appropriate mode
launcher = BotLauncher.new(Application.instance.telegram_bot_handler)
Application.instance.logger.info "BotLauncher initialized for mode: #{AppConfig.bot_mode}"
Application.instance.logger.info 'Starting bot...'
launcher.start
