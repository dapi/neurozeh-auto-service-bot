#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'config/environment'

# Launch bot with appropriate mode
launcher = BotLauncher.new(Application.config, Application.logger, Application.telegram_bot_handler)
Application.logger.info "BotLauncher initialized for mode: #{Application.config.bot_mode}"
Application.logger.info 'Starting bot...'
launcher.start
