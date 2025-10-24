#!/usr/bin/env ruby
# frozen_string_literal: true

require_relative 'config/environment'

# Launch bot with appropriate mode
launcher = BotLauncher.new(Application.telegram_bot_handler)
Application.logger.info "BotLauncher initialized for mode: #{AppConfig.bot_mode}"
Application.logger.info 'Starting bot...'
launcher.start
