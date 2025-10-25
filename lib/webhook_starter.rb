# frozen_string_literal: true

require 'logger'
require 'webrick'
require 'json'
require 'telegram/bot'

class WebhookStarter
  attr_reader :server

  def initialize(telegram_bot_handler)
    @telegram_bot_handler = telegram_bot_handler
    @server = nil
  end

  def start
    Application.instance.logger.info 'Webhook mode started'
    Application.instance.logger.info "Webhook URL: #{AppConfig.webhook_url}"
    Application.instance.logger.info "Server: #{AppConfig.webhook_host}:#{AppConfig.webhook_port}"

    setup_webhook
    start_http_server
  end

  private

  def setup_webhook
    Application.instance.logger.info 'Registering webhook with Telegram...'

    begin
      url = "#{AppConfig.webhook_url}#{AppConfig.webhook_path}"

      Telegram::Bot::Client.new(AppConfig.telegram_bot_token).tap do |bot|
        response = bot.api.set_webhook(url: url)

        raise 'Failed to register webhook' unless response

        Application.instance.logger.info "Webhook registered successfully: #{url}"
      end
    rescue StandardError => e
      Application.instance.logger.error "Error registering webhook: #{e.message}"
      raise
    end
  end

  def start_http_server
    Application.instance.logger.info "Starting HTTP server on #{AppConfig.webhook_host}:#{AppConfig.webhook_port}"

    server_config = {
      Port: AppConfig.webhook_port,
      BindAddress: AppConfig.webhook_host,
      AccessLog: [], # Отключить access логи
      Logger: WEBrick::Log.new($stdout, WEBrick::Log::DEBUG)
    }

    @server = WEBrick::HTTPServer.new(server_config)

    # Регистрируем маршрут для вебхука
    @server.mount_proc(AppConfig.webhook_path) do |req, res|
      handle_webhook_request(req, res)
    end

    # Graceful shutdown
    trap('INT') do
      Application.instance.logger.info 'Received SIGINT, shutting down webhook server...'
      @server.shutdown
    end

    Application.instance.logger.info "Listening for webhook requests on #{AppConfig.webhook_path}"
    @server.start
  end

  def handle_webhook_request(req, res)
    return handle_non_post(res) unless req.request_method == 'POST'

    body = req.body.read
    Application.instance.logger.debug "Received webhook request: #{body[0..200]}"

    update_data = JSON.parse(body)

    # Конвертируем JSON в Telegram::Bot::Types::Update
    update = Telegram::Bot::Types::Update.new(update_data)

    # Обрабатываем сообщение если оно есть
    @telegram_bot_handler.handle_update(update) if update.message

    res.status = 200
    res.content_type = 'application/json'
    res.body = { ok: true }.to_json

    Application.instance.logger.debug 'Webhook request processed successfully'
  rescue JSON::ParserError => e
    Application.instance.logger.error "Invalid JSON in webhook request: #{e.message}"
    res.status = 400
    res.body = { ok: false, error: 'Invalid JSON' }.to_json
  rescue StandardError => e
    Application.instance.logger.error "Error processing webhook request: #{e.message}"
    Application.instance.logger.debug e.backtrace.join("\n")
    res.status = 500
    res.body = { ok: false, error: 'Internal server error' }.to_json
  end

  def handle_non_post(res)
    res.status = 405
    res.body = { ok: false, error: 'Method not allowed' }.to_json
  end
end
