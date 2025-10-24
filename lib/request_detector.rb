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
  param :car_info, desc: "Информация об автомобиле (марка, модель, класс, пробег)", required: false
  param :required_services, desc: "Перечень необходимых работ", required: false
  param :cost_calculation, desc: "Расчет стоимости услуг", required: false
  param :dialog_context, desc: "Контекст диалога для понимания ситуации", required: false

  def initialize(config, logger = nil)
    @config = config
    @logger = logger || Logger.new(IO::NULL)
    @enriched_data = {}
  end

  # Метод для установки обогащенных данных извне
  def enrich_with(car_info:, required_services:, cost_calculation:, dialog_context:)
    @enriched_data = {
      car_info: car_info,
      required_services: required_services,
      cost_calculation: cost_calculation,
      dialog_context: dialog_context
    }
    @logger.debug "RequestDetector enriched with data: #{@enriched_data.keys}"
  end

  # Метод для получения обогащенных данных
  def enriched_data
    @enriched_data
  end

  def execute(message_text:, user_id:, username: nil, first_name: nil, conversation_context: nil,
              car_info: nil, required_services: nil, cost_calculation: nil, dialog_context: nil)
    @logger.info "Request detected for user #{user_id}: #{message_text[0..50]}..."

    # LLM уже определил(а), что это заявка на услугу, поэтому сразу обрабатываем её
    @logger.info "Processing service request - confirmed by LLM"
    admin_chat_id = @config.respond_to?(:admin_chat_id) ? @config.admin_chat_id : nil

    # Обогащенные данные имеют приоритет над переданными параметрами
    final_car_info = @enriched_data[:car_info] || car_info
    final_required_services = @enriched_data[:required_services] || required_services
    final_cost_calculation = @enriched_data[:cost_calculation] || cost_calculation
    final_dialog_context = @enriched_data[:dialog_context] || dialog_context

    # Создаем безопасную структуру данных для заявки
    request_info = {
      confidence: 1.0, # максимальная уверенность, т.к. вызвано LLM
      original_text: message_text || '',
      car_info: final_car_info || {},
      required_services: final_required_services || [],
      cost_calculation: final_cost_calculation || {},
      dialog_context: final_dialog_context || ''
    }

    result = send_to_admin_chat(request_info, user_id, username, first_name, admin_chat_id)

    if result[:success]
      return {
        success: true,
        message: "Заявка отправлена администратору"
      }
    else
      return {
        success: false,
        error: result[:error]
      }
    end
  rescue StandardError => e
    @logger.error "❌ REQUEST ERROR: #{e.class}: #{e.message}"
    @logger.error "Full backtrace:"
    e.backtrace&.each { |line| @logger.error "  #{line}" }
    { error: e.message }
  end

  private

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
      @logger.error "❌ REQUEST ERROR: Unexpected error sending admin notification: #{e.class}: #{e.message}"
      @logger.error "Full backtrace:"
      e.backtrace&.each { |line| @logger.error "  #{line}" }
      { error: "Unexpected error: #{e.message}" }
    end
  end

  def format_admin_notification(request_info, user_id, username, first_name)
    # Базовая информация
    notification = format_basic_info(request_info, user_id, username, first_name)

    # Обогащенная информация
    notification += format_car_info(request_info[:car_info])
    notification += format_required_services(request_info[:required_services])
    notification += format_cost_calculation(request_info[:cost_calculation])
    notification += format_dialog_context(request_info[:dialog_context])
    notification += format_action_buttons(user_id)

    notification
  end

  def format_basic_info(request_info, user_id, username, first_name)
    user_link = if username
                   "[@#{username}](https://t.me/#{username})"
                 else
                   first_name || "User##{user_id}"
                 end

    notification = "🔔 **НОВАЯ ЗАЯВКА**\n\n"
    notification += "👤 **Клиент:** #{user_link} - `#{user_id}`\n\n"

    # Сохраняем обратную совместимость с старым форматом
    if request_info[:matched_patterns] && !request_info[:matched_patterns].empty?
      notification += "🔍 **Распознанные паттерны:**\n"
      Array(request_info[:matched_patterns]).first(3).each do |pattern|
        # Ensure pattern is a string before splitting
        pattern_str = pattern.to_s
        type, pattern_text = pattern_str.split(':', 2)
        notification += "• #{type}: `#{pattern_text}`\n"
      end
      notification += "\n"
    end

    notification += "💬 **Сообщение:**\n"
    notification += "```\n#{request_info[:original_text]}\n```\n\n"

    notification
  end

  def format_car_info(car_info)
    return "" unless car_info && !car_info.empty?

    info = "\n🚗 **Информация об автомобиле:**\n"

    # Проверяем наличие данных
    has_data = false

    if car_info[:make_model]
      info += "• **Марка и модель:** #{car_info[:make_model]}\n"
      has_data = true
    end

    if car_info[:year]
      info += "• **Год выпуска:** #{car_info[:year]}\n"
      has_data = true
    end

    if car_info[:class]
      class_desc = car_info[:class_description] || car_info[:class]
      info += "• **Класс автомобиля:** #{class_desc}\n"
      has_data = true
    else
      info += "• **Класс автомобиля:** требуется уточнение\n"
      has_data = true
    end

    if car_info[:mileage]
      info += "• **Пробег:** #{car_info[:mileage]}\n"
      has_data = true
    end

    info += "\n" if has_data
    info
  end

  def format_required_services(services)
    return "" unless services && !services.empty?

    info = "\n🔧 **Необходимые работы:**\n"
    Array(services).each_with_index do |service, index|
      # Ensure service is convertible to string
      service_str = service.to_s
      info += "#{index + 1}. #{service_str}\n"
    end
    info += "\n"
  end

  def format_cost_calculation(cost_data)
    return "" unless cost_data && !cost_data.empty?

    info = "\n💰 **Расчет стоимости:**\n"
    has_data = false

    if cost_data[:services] && !cost_data[:services].empty?
      Array(cost_data[:services]).each do |service|
        # Ensure service is a hash with expected keys
        if service.is_a?(Hash)
          service_name = service[:name] || service['name'] || 'Неизвестная услуга'
          service_price = service[:price] || service['price'] || 'по запросу'
          info += "• #{service_name}: #{service_price}\n"
        else
          info += "• #{service.to_s}\n"
        end
      end
      has_data = true
    end

    if cost_data[:total]
      info += "• **Итого базовая стоимость:** #{cost_data[:total]}\n"
      has_data = true
    end

    note = cost_data[:note] || 'Окончательная стоимость определяется после диагностики'
    info += "• *#{note}*\n"
    has_data = true

    info += "\n" if has_data
    info
  end

  def format_dialog_context(context)
    return "" unless context && !context.to_s.strip.empty?

    info = "\n💬 **Контекст диалога:**\n"
    info += "#{context}\n\n"
    info
  end

  def format_action_buttons(user_id)
    "\n🔗 **Действия:**\n/answer_#{user_id} - Ответить клиенту\n/close_#{user_id} - Закрыть заявку\n"
  end
end
