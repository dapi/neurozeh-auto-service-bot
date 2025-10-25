# frozen_string_literal: true

require 'ruby_llm'
require 'logger'
require_relative 'request_detector'
require_relative 'dialog_analyzer'
require_relative 'telegram_markdown_sanitizer'

class LLMClient
  MAX_RETRIES = 1

  def initialize(conversation_manager = nil, logger = nil)
    @conversation_manager = conversation_manager || ConversationManager.new
    @logger = logger || @logger
    @markdown_sanitizer = TelegramMarkdownSanitizer.new(logger: @logger)
  end

  # Новый метод - отправка сообщения с использованием персистентного чата
  def send_message_to_user(user_info, message_content, additional_context = nil)
    # Trace логирование для отслеживания источника запроса
    caller_info = caller_locations(1, 1).first
    @logger.info "🔍 LLM CLIENT TRACE: Called from #{caller_info.path}:#{caller_info.lineno}"
    @logger.info "Sending message to user #{user_info[:id]}"
    @logger.debug "🔍 OUTGOING MESSAGE TRACE:"
    @logger.debug "  User: #{user_info[:id]} (#{user_info[:first_name]} #{user_info[:last_name]})"
    @logger.debug "  Message length: #{message_content.length} chars"
    @logger.debug "  Message preview: #{message_content[0..100].inspect}#{'...' if message_content.length > 100}"
    @logger.debug "  Additional context: #{additional_context ? 'YES' : 'NO'}"

    # Получаем или создаем чат для пользователя
    db_chat = @conversation_manager.get_or_create_chat(user_info)

    # Используем персистентный чат из базы данных
    @logger.debug "Using persistent chat ##{db_chat.id}"

    retries = 0
    begin
      @logger.info "LLMClient using model: #{AppConfig.llm_model}, provider: #{AppConfig.llm_provider}"

      # Устанавливаем модель динамически
      chat = db_chat.with_model(AppConfig.llm_model, provider: AppConfig.llm_provider.to_sym)

      # Комбинируем системный промпт
      combined_system_prompt = build_combined_system_prompt

      # Добавляем дополнительный контекст если есть
      if additional_context
        contextual_content = "#{additional_context}\n\n#{message_content}"
        message_content = contextual_content
      end

      # Устанавливаем системные инструкции
      chat.with_instructions(combined_system_prompt, replace: true)

      # Добавляем RequestDetector tool если настроен admin_chat_id
      if AppConfig.admin_chat_id
        request_detector = create_enriched_request_detector(db_chat, user_info)
        chat.with_tool(request_detector)
      end

      # Отправляем сообщение - acts_as_chat автоматически сохранит сообщения
      response = chat.ask(message_content)

      @logger.info "Response received for user #{user_info[:id]}, tokens: #{response.input_tokens + response.output_tokens}"

      # Санитизируем markdown для Telegram API
      sanitized_content = @markdown_sanitizer.sanitize(response.content)

      # Логируем если контент был изменен
      if response.content != sanitized_content
        @logger.debug "Markdown sanitization applied: #{response.content.length} -> #{sanitized_content.length} chars"
        @logger.debug "Original: #{response.content[0..100].inspect}#{'...' if response.content.length > 100}"
        @logger.debug "Sanitized: #{sanitized_content[0..100].inspect}#{'...' if sanitized_content.length > 100}"
      end

      sanitized_content

    rescue RubyLLM::ConfigurationError => e
      @logger.error "RubyLLM configuration error: #{e.message}"
      raise e
    rescue RubyLLM::ModelNotFoundError => e
      @logger.error "Model not found error: #{e.message}"
      raise e
    rescue RubyLLM::Error => e
      @logger.error "RubyLLM API error: #{e.message}"
      raise e
    rescue StandardError => e
      retries += 1
      if retries <= MAX_RETRIES
        @logger.warn "LLM client retry #{retries}/#{MAX_RETRIES}: #{e.message}"
        @logger.warn "Backtrace:\n#{e.backtrace.join("\n")}" if retries == MAX_RETRIES
        sleep(1)
        retry
      else
        @logger.error "Failed to send message to RubyLLM after #{MAX_RETRIES} retries: #{e.message}"
        @logger.error "Backtrace:\n#{e.backtrace.join("\n")}"
        raise e
      end
    end
  end

  # Старый метод для совместимости
  def send_message(messages, user_info = nil)
    return "No user info provided" unless user_info

    # Получаем последнее сообщение
    last_message = messages.is_a?(Array) ? messages.last : messages
    return "No message content" unless last_message && last_message[:content]

    send_message_to_user(user_info, last_message[:content])
  end

  private

  def build_combined_system_prompt
    # Заменяем плейсхолдер [COMPANY_INFO] на содержимое файла с информацией о компании
    prompt_with_company = AppConfig.system_prompt.gsub('[COMPANY_INFO]', AppConfig.company_info)

    # Добавляем прайс-лист
    "#{prompt_with_company}\n\n---\n\n## ПРАЙС-ЛИСТ\n\n#{AppConfig.formatted_price_list}"
  end

  def create_enriched_request_detector(chat, user_info)
    @logger.debug "Creating enriched RequestDetector for user #{user_info[:id]}"

    # Извлекаем информацию из диалога через conversation_manager
    messages_array = @conversation_manager.get_history(user_info[:id])

    dialog_analyzer = DialogAnalyzer.new

    car_info = dialog_analyzer.extract_car_info(messages_array)
    required_services = dialog_analyzer.extract_services(messages_array)
    dialog_context = dialog_analyzer.extract_dialog_context(messages_array)

    # Извлекаем последнюю названную общую стоимость
    total_cost_to_user = dialog_analyzer.extract_last_total_cost(messages_array)
    @logger.debug "Extracted total cost to user: #{total_cost_to_user}" if total_cost_to_user

    # Создаем краткую выжимку из переписки
    conversation_summary = dialog_analyzer.extract_conversation_summary(messages_array)
    @logger.debug "Generated conversation summary with #{conversation_summary.length} characters"

    # Не рассчитываем стоимость - она уже есть в ответах бота пользователю
    cost_calculation = nil
    @logger.debug "Skipping cost calculation - using extracted total cost: #{total_cost_to_user}"

    # Создаем RequestDetector
    detector = RequestDetector.new

    # Обогащаем дополнительными данными
    detector.enrich_with(
      car_info: car_info,
      required_services: required_services,
      cost_calculation: cost_calculation,
      dialog_context: dialog_context,
      total_cost_to_user: total_cost_to_user,
      conversation_summary: conversation_summary
    )

    detector
  rescue StandardError => e
    @logger.error "Error creating enriched RequestDetector: #{e.message}"
    @logger.error "Backtrace: #{e.backtrace.first(5).join("\n")}"
    # Возвращаем базовый RequestDetector в случае ошибки
    RequestDetector.new
  end
end