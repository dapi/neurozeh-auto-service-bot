# frozen_string_literal: true

require 'telegram/bot'
require 'logger'
require_relative 'telegram_markdown_sanitizer'

class TelegramBotHandler
  def initialize(ai_client, rate_limiter, conversation_manager, logger = nil)
    @ai_client = ai_client
    @rate_limiter = rate_limiter
    @conversation_manager = conversation_manager
    @logger = logger || @logger
    @markdown_sanitizer = TelegramMarkdownSanitizer.new(logger: @logger)
  end

  def handle_polling
    @logger.info "Starting Telegram bot with token: #{AppConfig.telegram_bot_token[0..10]}..."

    # Используем встроенный метод Telegram::Bot::Client.run для правильного polling
    Telegram::Bot::Client.run(AppConfig.telegram_bot_token, logger: @logger) do |bot|
      @logger.info 'Telegram bot client initialized successfully'

      # Тестируем соединение
      begin
        me = bot.api.get_me
        @logger.info "Connected to bot #{me['result']['first_name']} (@#{me['result']['username']})"
      rescue StandardError => e
        @logger.error "Failed to connect to Telegram API: #{e.class} - #{e.message}"
        raise e
      end

      @logger.info 'Starting polling loop...'

      bot.listen do |update|
        process_update(update, bot)
      rescue Telegram::Bot::Exceptions::ResponseError => e
        @logger.error "Telegram API error: #{e.class} - #{e.message}"
        @logger.error "Error code: #{e.error_code}" if e.respond_to?(:error_code)
        @logger.error "Response body: #{e.response.body}" if e.respond_to?(:response)
      rescue StandardError => e
        @logger.error "Error processing update: #{e.class} - #{e.message}"
        @logger.error "Backtrace: #{e.backtrace.first(5).join("\n")}"
      end
    end
  rescue StandardError => e
    @logger.error "Fatal error in polling: #{e.class} - #{e.message}"
    @logger.error "Backtrace: #{e.backtrace.first(10).join("\n")}"
    raise e
  end

  def handle_update(update)
    Telegram::Bot::Client.new(AppConfig.telegram_bot_token) do |bot|
      process_update(update, bot)
    end
  end

  private

  def handle_new_chat_members(message, bot)
    chat = message.chat
    added_by = message.from

    # Проверка, добавлен ли бот
    bot_added = message.new_chat_members.any? { |member| member.is_bot }
    return unless bot_added

    # Логирование информации о чате
    log_chat_info(chat, added_by)

    # Отправка приветственного сообщения
    send_chat_welcome_message(chat.id, bot)
  end

  def handle_chat_created(message, bot)
    chat = message.chat
    creator = message.from

    # Логирование создания нового чата
    log_chat_creation(chat, creator)

    # Отправка приветственного сообщения
    send_chat_welcome_message(chat.id, bot)
  end

  def log_chat_info(chat, added_by)
    chat_info = format_chat_info(chat, added_by)
    @logger.info "Bot added to chat | #{chat_info}"

    # Детальная информация в JSON формате
    detailed_info = build_detailed_chat_info(chat, added_by)
    @logger.debug "Detailed chat info: #{detailed_info.to_json}"
  end

  def log_chat_creation(chat, creator)
    chat_info = format_chat_creation_info(chat, creator)
    @logger.info "New chat created with bot | #{chat_info}"

    # Детальная информация в JSON формате
    detailed_info = build_detailed_chat_info(chat, creator, "chat_created")
    @logger.debug "Detailed chat creation info: #{detailed_info.to_json}"
  end

  def format_chat_info(chat, added_by)
    type_info = chat.type
    title_info = chat.title ? "Title: \"#{chat.title}\"" : ""
    username_info = chat.username ? "Username: @#{chat.username}" : ""
    added_by_info = "#{added_by.id} (#{added_by.first_name}#{added_by.last_name ? " #{added_by.last_name}" : ""})"

    parts = ["Chat ID: #{chat.id}", "Type: #{type_info}"]
    parts << title_info unless title_info.empty?
    parts << username_info unless username_info.empty?
    parts << "Added by: #{added_by_info}"

    parts.join(" | ")
  end

  def format_chat_creation_info(chat, creator)
    type_info = chat.type == "supergroup" ? "supergroup" : chat.type
    title_info = chat.title ? "Title: \"#{chat.title}\"" : ""
    creator_info = "#{creator.id} (#{creator.first_name}#{creator.last_name ? " #{creator.last_name}" : ""})"

    parts = ["Chat ID: #{chat.id}", "Type: #{type_info}"]
    parts << title_info unless title_info.empty?
    parts << "Creator: #{creator_info}"

    parts.join(" | ")
  end

  def build_detailed_chat_info(chat, user, event_type = "bot_added_to_chat")
    {
      event: event_type,
      timestamp: Time.now.utc.iso8601,
      chat: {
        id: chat.id,
        type: chat.type,
        title: chat.title,
        username: chat.username,
        description: chat.description
      }.compact,
      user: {
        id: user.id,
        first_name: user.first_name,
        last_name: user.last_name,
        username: user.username,
        language_code: user.language_code,
        is_bot: user.is_bot
      }.compact
    }
  end

  def send_chat_welcome_message(chat_id, bot)
    welcome_text = "👋 Здравствуйте! Я был добавлен в этот чат. Я помогу вам с вопросами по автосервису. Используйте /start для начала работы."

    send_message_with_fallback(bot, chat_id, welcome_text)
  rescue StandardError => e
    @logger.error "Failed to send welcome message to chat #{chat_id}: #{e.message}"
  end

  def process_update(update, bot)
    # Handle different types of updates
    if update.respond_to?(:message) && update.message
      process_message(update.message, bot)
    elsif update.respond_to?(:chat_member) && update.chat_member
      handle_chat_member_updated(update.chat_member, bot)
    elsif update.is_a?(Telegram::Bot::Types::Message)
      # If update is already a message object
      process_message(update, bot)
    end
  end

  def process_message(message, bot)
    # Validate message object
    unless message.respond_to?(:from) && message.from.respond_to?(:id)
      @logger.error "Invalid message object: #{message.class}"
      return
    end

    user_id = message.from.id

    # Handle new chat members event
    if message.respond_to?(:new_chat_members) && message.new_chat_members.present?
      handle_new_chat_members(message, bot)
      return
    end

    # Handle chat creation events
    if (message.respond_to?(:group_chat_created) && message.group_chat_created.present?) ||
        (message.respond_to?(:supergroup_chat_created) && message.supergroup_chat_created.present?) ||
        (message.respond_to?(:channel_chat_created) && message.channel_chat_created.present?)
      handle_chat_created(message, bot)
      return
    end

    begin
      text = message.respond_to?(:text) ? message.text : nil
      chat_id = message.chat.id
    rescue StandardError => e
      @logger.error "Error extracting message data: #{e.class} - #{e.message}"
      return
    end

    # Handle /start command
    if text && text.start_with?('/start')
      @logger.info "User #{user_id} issued /start command"
      @conversation_manager.clear_history(user_id)

      # Use welcome message from config
      send_message_with_fallback(bot, chat_id, AppConfig.welcome_message)
      return
    end

    # Handle /reset command
    if text && text.start_with?('/reset')
      @logger.info "User #{user_id} issued /reset command"

      if @conversation_manager.clear_history(user_id)
        send_message_with_fallback(bot, chat_id, '✅ Диалог сброшен. Можем начать разговор заново!')
        @logger.info "User #{user_id} issued /reset command - success"
      else
        send_message_with_fallback(bot, chat_id, '❌ Не удалось сбросить диалог. Попробуйте позже.')
        @logger.error "User #{user_id} issued /reset command - failed"
      end
      return
    end

    # Check rate limit
    unless @rate_limiter.allow?(user_id)
      @logger.warn "Rate limit exceeded for user #{user_id}"
      send_message_with_fallback(bot, chat_id, 'Вы отправляете слишком много сообщений. Пожалуйста, подождите немного.')
      return
    end

    # Only process text messages
    unless text && !text.strip.empty?
      return
    end

    # Process message with Claude
    begin
      # Подготовка информации о пользователе
      user_info = extract_user_info(message.from)
      user_info[:chat_id] = chat_id

      # Send to AI API with persistent chat
      response = @ai_client.send_message_to_user(user_info, text)

      # Send response to user
      send_message_with_fallback(bot, chat_id, response)
    rescue StandardError => e
      @logger.error "Error processing message for user #{user_id}: #{e.message}"
      @logger.error "Backtrace:\n#{e.backtrace.join("\n")}"
      send_message_with_fallback(bot, chat_id, 'Произошла ошибка при обработке вашего сообщения. Пожалуйста, попробуйте позже.')
    end
  end

  def handle_chat_member_updated(chat_member_update, bot)
    chat = chat_member_update.chat
    from_user = chat_member_update.from
    old_chat_member = chat_member_update.old_chat_member
    new_chat_member = chat_member_update.new_chat_member

    @logger.info "Chat member updated in chat #{chat.id} by user #{from_user.id}"
    @logger.debug "Old status: #{old_chat_member.status}, New status: #{new_chat_member.status}"

    # Handle bot being removed from chat
    if new_chat_member.user.is_bot && new_chat_member.status == 'kicked'
      @logger.info "Bot was removed from chat #{chat.id} by user #{from_user.id}"
      # Clear conversation history for the chat
      @conversation_manager.clear_history(chat.id)
    end

    # Handle bot being added to chat
    if new_chat_member.user.is_bot && new_chat_member.status == 'member'
      @logger.info "Bot was added to chat #{chat.id} by user #{from_user.id}"
      log_chat_info(chat, from_user)
      send_chat_welcome_message(chat.id, bot)
    end
  rescue StandardError => e
    @logger.error "Error handling chat member update: #{e.message}"
  end

  def extract_user_info(user)
    {
      id: user.id,
      username: user.username,
      first_name: user.first_name,
      last_name: user.last_name
    }
  end

  def send_message_with_fallback(bot, chat_id, text, parse_mode = 'Markdown')
    begin
      # First try with the requested parse_mode
      bot.api.send_message(
        chat_id: chat_id,
        text: text,
        parse_mode: parse_mode
      )
      @logger.debug "Message sent successfully with parse_mode: #{parse_mode}"
    rescue Telegram::Bot::Exceptions::ResponseError => e
      if e.message.include?('can\'t parse entities') || e.message.include?('Bad Request: can\'t parse')
        @logger.warn "Markdown parsing failed for chat #{chat_id}, falling back to plain text"
        @logger.debug "Markdown error: #{e.message}"

        # Fallback to plain text by escaping all markdown
        plain_text = @markdown_sanitizer.send(:escape_all_markdown, text)

        bot.api.send_message(
          chat_id: chat_id,
          text: plain_text
        )
        @logger.info "Message sent with plain text fallback for chat #{chat_id}"
      else
        # Re-raise non-markdown related errors
        raise e
      end
    end
  rescue StandardError => e
    @logger.error "Failed to send message to chat #{chat_id}: #{e.message}"
    @logger.error "Error class: #{e.class}"
    @logger.error "Message preview: #{text[0..100].inspect}"
    raise e
  end
end
