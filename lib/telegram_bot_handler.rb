# frozen_string_literal: true

require 'telegram/bot'
require 'logger'

class TelegramBotHandler
  def initialize(config, ai_client, rate_limiter, conversation_manager, logger = Logger.new($stdout))
    @config = config
    @ai_client = ai_client
    @rate_limiter = rate_limiter
    @conversation_manager = conversation_manager
    @logger = logger
  end

  def handle_polling
    @logger.info "Starting Telegram bot with token: #{@config.telegram_bot_token[0..10]}..."
    
    # Используем встроенный метод Telegram::Bot::Client.run для правильного polling
    Telegram::Bot::Client.run(@config.telegram_bot_token, logger: @logger) do |bot|
      @logger.info 'Telegram bot client initialized successfully'

      # Тестируем соединение
      begin
        me = bot.api.get_me
        @logger.info "SUCCESS: Connected to bot #{me['result']['first_name']} (@#{me['result']['username']})"
      rescue StandardError => e
        @logger.error "Failed to connect to Telegram API: #{e.class} - #{e.message}"
        raise e
      end

      @logger.info 'Starting polling loop...'

      bot.listen do |message|
        
        process_message(message, bot)
      rescue Telegram::Bot::Exceptions::ResponseError => e
        @logger.error "Telegram API error: #{e.class} - #{e.message}"
        @logger.error "Error code: #{e.error_code}" if e.respond_to?(:error_code)
        @logger.error "Response body: #{e.response.body}" if e.respond_to?(:response)
      rescue StandardError => e
        @logger.error "Error processing message: #{e.class} - #{e.message}"
      end
    end
  rescue StandardError => e
    @logger.error "Fatal error in polling: #{e.class} - #{e.message}"
    @logger.error "Backtrace: #{e.backtrace.first(10).join("\n")}"
    raise e
  end

  def handle_update(update)
    message = update.message
    return unless message

    Telegram::Bot::Client.new(@config.telegram_bot_token) do |bot|
      process_message(message, bot)
    end
  end

  private

  def process_message(message, bot)
    user_id = message.from.id
    text = message.text
    chat_id = message.chat.id

    @logger.info "Received message from user #{user_id}: #{text[0..50]}..."

    # Handle /start command
    if text&.start_with?('/start')
      @logger.info "User #{user_id} issued /start command"
      @conversation_manager.clear_history(user_id)

      # Read welcome message from file
      welcome_text = read_welcome_message

      bot.api.send_message(
        chat_id: chat_id,
        text: welcome_text,
        parse_mode: 'Markdown'
      )
      return
    end

    # Check rate limit
    unless @rate_limiter.allow?(user_id)
      @logger.warn "Rate limit exceeded for user #{user_id}"
      @rate_limiter.remaining_requests(user_id)
      bot.api.send_message(
        chat_id: chat_id,
        text: 'Вы отправляете слишком много сообщений. Пожалуйста, подождите немного.'
      )
      return
    end

    # Process message with Claude
    begin
      # Add user message to history
      @conversation_manager.add_message(user_id, 'user', text)

      # Get conversation history
      history = @conversation_manager.get_history(user_id)

      # Send to AI API
      response = @ai_client.send_message(history)

      # Add assistant response to history
      @conversation_manager.add_message(user_id, 'assistant', response)

      # Send response to user
      bot.api.send_message(
        chat_id: chat_id,
        text: response,
        parse_mode: 'Markdown'
      )

      @logger.info "Successfully processed message for user #{user_id}"
    rescue StandardError => e
      @logger.error "Error processing message for user #{user_id}: #{e.message}"
      bot.api.send_message(
        chat_id: chat_id,
        text: 'Произошла ошибка при обработке вашего сообщения. Пожалуйста, попробуйте позже.'
      )
    end
  end

  def read_welcome_message
    File.read(@config.welcome_message_path)
  rescue StandardError => e
    @logger.error "Error reading welcome message: #{e.message}"
    # Fallback сообщение на случай ошибки чтения файла
    'Привет! Я бот для записи на услуги автосервиса. Чем я могу вам помочь?'
  end
end
