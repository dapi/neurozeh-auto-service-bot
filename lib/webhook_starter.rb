# frozen_string_literal: true

require 'logger'
require 'webrick'
require 'json'
require 'telegram/bot'

class WebhookStarter
  attr_reader :server

  def initialize(config, logger, telegram_bot_handler)
    @config = config
    @logger = logger
    @telegram_bot_handler = telegram_bot_handler
    @server = nil
  end

  def start
    @logger.info 'Webhook mode started'
    @logger.info "Webhook URL: #{@config.webhook_url}"
    @logger.info "Server: #{@config.webhook_host}:#{@config.webhook_port}"

    setup_webhook
    start_http_server
  end

  private

  def setup_webhook
    @logger.info 'Registering webhook with Telegram...'

    begin
      url = "#{@config.webhook_url}#{@config.webhook_path}"

      Telegram::Bot::Client.new(@config.telegram_bot_token).tap do |bot|
        response = bot.api.set_webhook(url: url)

        raise 'Failed to register webhook' unless response

        @logger.info "Webhook registered successfully: #{url}"
      end
    rescue StandardError => e
      @logger.error "Error registering webhook: #{e.message}"
      raise
    end
  end

  def start_http_server
    @logger.info "Starting HTTP server on #{@config.webhook_host}:#{@config.webhook_port}"

    server_config = {
      Port: @config.webhook_port,
      BindAddress: @config.webhook_host,
      AccessLog: [], # Отключить access логи
      Logger: WEBrick::Log.new($stdout, WEBrick::Log::DEBUG)
    }

    @server = WEBrick::HTTPServer.new(server_config)

    # Регистрируем маршрут для вебхука
    @server.mount_proc(@config.webhook_path) do |req, res|
      handle_webhook_request(req, res)
    end

    # Graceful shutdown
    trap('INT') do
      @logger.info 'Received SIGINT, shutting down webhook server...'
      @server.shutdown
    end

    @logger.info "Listening for webhook requests on #{@config.webhook_path}"
    @server.start
  end

  def handle_webhook_request(req, res)
    return handle_non_post(res) unless req.request_method == 'POST'

    body = req.body.read
    @logger.debug "Received webhook request: #{body[0..200]}"

    update_data = JSON.parse(body)

    # Конвертируем JSON в Telegram::Bot::Types::Update
    update = Telegram::Bot::Types::Update.new(update_data)

    # Обрабатываем сообщение если оно есть
    @telegram_bot_handler.handle_update(update) if update.message

    res.status = 200
    res.content_type = 'application/json'
    res.body = { ok: true }.to_json

    @logger.debug 'Webhook request processed successfully'
  rescue JSON::ParserError => e
    @logger.error "Invalid JSON in webhook request: #{e.message}"
    res.status = 400
    res.body = { ok: false, error: 'Invalid JSON' }.to_json
  rescue StandardError => e
    @logger.error "Error processing webhook request: #{e.message}"
    @logger.debug e.backtrace.join("\n")
    res.status = 500
    res.body = { ok: false, error: 'Internal server error' }.to_json
  end

  def handle_non_post(res)
    res.status = 405
    res.body = { ok: false, error: 'Method not allowed' }.to_json
  end
end
