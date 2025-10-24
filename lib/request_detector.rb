# frozen_string_literal: true

require 'ruby_llm'
require 'telegram/bot'

class RequestDetector < RubyLLM::Tool
  description "Определяет является ли сообщение клиента заявкой на услугу и отправляет ее в административный чат"

  param :message_text, desc: "Текст сообщения от клиента"
  param :user_id, desc: "ID пользователя в Telegram", type: :integer
  param :username, desc: "Username пользователя", required: false
  param :first_name, desc: "Имя пользователя", required: false
  param :conversation_context, desc: "Контекст диалога (последние сообщения)", required: false

  def initialize(config, logger = nil)
    @config = config
    @logger = logger || Logger.new(IO::NULL)
  end

  def execute(message_text:, user_id:, username: nil, first_name: nil, conversation_context: nil)
    @logger.info "RequestDetector analyzing message from user #{user_id}: #{message_text[0..50]}..."

    # Проверяем конфигурацию
    admin_chat_id = @config.respond_to?(:admin_chat_id) ? @config.admin_chat_id : nil
    unless admin_chat_id
      @logger.warn "Admin chat not configured, skipping request detection"
      return { error: "Admin chat not configured" }
    end

    # Анализируем сообщение на предмет заявки
    request_info = analyze_request(message_text, conversation_context)

    if request_info[:is_request]
      @logger.info "Request detected: #{request_info[:type]} - #{request_info[:confidence]} confidence"
      result = send_to_admin_chat(request_info, user_id, username, first_name, admin_chat_id)

      if result[:success]
        return {
          success: true,
          request_type: request_info[:type],
          message: "Заявка отправлена администратору"
        }
      else
        return {
          success: false,
          error: result[:error]
        }
      end
    else
      @logger.debug "Message is not a request: #{request_info[:reason]}"
      return {
        success: false,
        reason: request_info[:reason]
      }
    end
  rescue StandardError => e
    @logger.error "Error in RequestDetector: #{e.message}"
    @logger.error e.backtrace.first(5).join("\n") if e.backtrace
    { error: e.message }
  end

  private

  def analyze_request(message_text, conversation_context)
    text = message_text.downcase

    # Определяем тип заявки и уверенность
    request_patterns = {
      # Прямые запросы на запись (наивысший приоритет)
      booking: {
        patterns: [
          /записат?/, /запись/, /хочу на сервис/, /нужен сервис/,
          /когда можно приехать/, /запишите/, /запишете/, /записаться/,
          /когда/, /смогу/, /приехать/
        ],
        weight: 0.95
      },

      # Запросы стоимости (высокий приоритет)
      pricing: {
        patterns: [
          /сколько стоит/, /цена/, /стоимость/, /расчет стоимости/,
          /смета/, /прайс/, /цену/, /стоит/
        ],
        weight: 0.9
      },

      # Запросы услуг и ремонта (средний приоритет)
      service: {
        patterns: [
          /\bдиагностик/, /\bпроверить/, /\bосмотр/, /\bзамена/,
          /\bто\b/, /\bобслуживание/, /\bтожу/, /\bто-/, /\bтехобслуживание/
          # Исключаем слова которые относятся к другим категориям
        ],
        weight: 0.8
      },

      # Консультационные запросы
      consultation: {
        patterns: [
          /\bпомогите выбрать\b/, /\bпосоветуйте\b/, /\bкак лучше\b/,
          /\bчто делать\b/, /\bпроблема с\b/, /\bсломалось/,
          /\bвыбрать\b/, /\bрекомендации\b/, /\bлучшие\b/
        ],
        weight: 0.7
      }
    }

    max_score = 0
    request_type = nil
    matched_patterns = []

    # Анализируем паттерны
    request_patterns.each do |type, config|
      score = 0
      config[:patterns].each do |pattern|
        if text.match?(pattern)
          score += config[:weight]
          matched_patterns << "#{type}:#{pattern.source}"
        end
      end

      if score > max_score
        max_score = score
        request_type = type
      end
    end

    # Дополнительные факторы для анализа
    confidence_multiplier = 1.0

    # Учитываем длину сообщения (большие сообщения чаще содержат заявки)
    if message_text.length > 50
      confidence_multiplier += 0.1
    end

    # Учитываем наличие вопросов
    if message_text.include?('?')
      confidence_multiplier += 0.05
    end

    # Учитываем контекст разговора
    if conversation_context && is_continuation_of_request?(conversation_context)
      confidence_multiplier += 0.15
    end

    final_score = max_score * confidence_multiplier
    threshold = 0.6  # Пороговое значение для определения заявки

    if final_score >= threshold
      return {
        is_request: true,
        type: request_type,
        confidence: final_score,
        matched_patterns: matched_patterns,
        original_text: message_text
      }
    else
      return {
        is_request: false,
        reason: "Score #{final_score.round(2)} below threshold #{threshold}",
        score: final_score
      }
    end
  end

  def is_continuation_of_request?(context)
    # Простая проверка - есть ли в предыдущих сообщениях упоминания услуг
    context_text = context.downcase
    service_keywords = %w[ремонт диагностика обслуживание замена то]
    service_keywords.any? { |keyword| context_text.include?(keyword) }
  end

  def send_to_admin_chat(request_info, user_id, username, first_name, admin_chat_id)
    begin
      # Создаем уведомление для админского чата
      notification = format_admin_notification(request_info, user_id, username, first_name)

      # Используем Telegram bot API для отправки
      telegram_token = @config.respond_to?(:telegram_bot_token) ? @config.telegram_bot_token : nil
      bot = Telegram::Bot::Client.new(telegram_token)

      bot.api.send_message(
        chat_id: admin_chat_id,
        text: notification,
        parse_mode: 'Markdown'
      )

      @logger.info "Request notification sent to admin chat #{admin_chat_id}"
      { success: true }
    rescue Telegram::Bot::Exceptions::ResponseError => e
      @logger.error "Failed to send admin notification: #{e.message}"
      { error: "Telegram API error: #{e.message}" }
    rescue StandardError => e
      @logger.error "Unexpected error sending admin notification: #{e.message}"
      { error: "Unexpected error: #{e.message}" }
    end
  end

  def format_admin_notification(request_info, user_id, username, first_name)
    user_link = if username
                   "@#{username}"
                 else
                   first_name || "User##{user_id}"
                 end

    type_mapping = {
      :booking => "📅 Запись на сервис",
      :pricing => "💰 Запрос стоимости",
      :service => "🔧 Запрос услуги",
      :consultation => "💬 Консультация"
    }

    request_type_display = type_mapping[request_info[:type]] || "📝 Запрос"

    notification = "🔔 **НОВАЯ ЗАЯВКА**\n\n"
    notification += "👤 **Клиент:** #{user_link} - `#{user_id}`\n"
    notification += "📋 **Тип:** #{request_type_display}\n"
    notification += "⏰ **Время:** #{Time.now.strftime('%Y-%m-%d %H:%M')}\n"
    notification += "🎯 **Уверенность:** #{(request_info[:confidence] * 100).round(1)}%\n\n"

    if request_info[:matched_patterns]&.any?
      notification += "🔍 **Распознанные паттерны:**\n"
      request_info[:matched_patterns].first(3).each do |pattern|
        type, pattern_text = pattern.split(':', 2)
        notification += "• #{type}: `#{pattern_text}`\n"
      end
      notification += "\n"
    end

    notification += "💬 **Сообщение:**\n"
    notification += "```\n#{request_info[:original_text]}\n```\n\n"

    notification += "🔗 **Действия:**\n"
    notification += "/answer_#{user_id} - Ответить клиенту\n"
    notification += "/close_#{user_id} - Закрыть заявку"

    notification
  end
end