# frozen_string_literal: true

require 'ruby_llm'
require 'logger'
require_relative 'request_detector'
require_relative 'dialog_analyzer'
require_relative 'cost_calculator'

class LLMClient
  MAX_RETRIES = 1

  def initialize(config, logger = Logger.new($stdout))
    @config = config
    @logger = logger
    @logger.info 'LLMClient initialized with system prompt and price list'
  end

  def send_message(messages, user_info = nil)

    # Комбинируем системный промпт с информацией о компании и прайс-листом
    combined_system_prompt = build_combined_system_prompt

    retries = 0
    begin
      # Определяем провайдера в зависимости от конфигурации
      @logger.info "LLMClient model: #{@config.llm_model}, provider: #{@config.llm_provider}"
      # Выбираем чат: кастомный или стандартный
      chat = RubyLLM.chat model: @config.llm_model, provider: @config.llm_provider, assume_model_exists: true

      # Устанавливаем системные инструкции
      chat.with_instructions(combined_system_prompt, replace: true)

      # Добавляем RequestDetector tool если настроен admin_chat_id и есть информация о пользователе
      if user_info && @config.admin_chat_id
        # Создаем обогащенный RequestDetector с предзаполненными данными
        request_detector = create_enriched_request_detector(messages, user_info)
        chat.with_tool(request_detector)
      end

      # Получаем последнее сообщение пользователя
      last_message = messages.last
      raise ArgumentError, 'No messages to send' unless last_message
      raise ArgumentError, 'Last message is not from user' unless last_message[:role] == 'user'

          # Добавляем контекст диалога в сообщение для AI, чтобы он мог использовать RequestDetector с нужными параметрами
      if user_info && @config.admin_chat_id && messages.length > 1
        context_messages = messages[0..-2]
        if context_messages && context_messages.any?
          conversation_context = context_messages.map { |msg| "#{msg[:role]}: #{msg[:content]}" }.join("\n\n")
          # Добавляем контекст в начало сообщения, чтобы AI мог анализировать всю беседу
          contextual_message = "Контекст диалога:\n#{conversation_context}\n\nТекущее сообщение пользователя: #{last_message[:content]}"
          last_message = { role: 'user', content: contextual_message }
        end
      end

      # Отправляем сообщение и получаем ответ
      response = chat.ask(last_message[:content])

      # Возвращаем текст ответа
      response.content
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
        sleep(1) # Wait before retrying
        retry
      else
        @logger.error "Failed to send message to RubyLLM after #{MAX_RETRIES} retries: #{e.message}"
        raise e
      end
    end
  end

  private

  def build_combined_system_prompt
    # Заменяем плейсхолдер [COMPANY_INFO] на содержимое файла с информацией о компании
    prompt_with_company = @config.system_prompt.gsub('[COMPANY_INFO]', @config.company_info)

    # Добавляем прайс-лист
    "#{prompt_with_company}\n\n---\n\n## ПРАЙС-ЛИСТ\n\n#{@config.formatted_price_list}"
  end

  def create_enriched_request_detector(messages, user_info)
    @logger.debug "Creating enriched RequestDetector for user #{user_info[:id]}"

    # Извлекаем информацию из диалога
    dialog_analyzer = DialogAnalyzer.new(@logger)
    cost_calculator = CostCalculator.new(@config.price_list_path, @logger)

    car_info = dialog_analyzer.extract_car_info(messages)
    required_services = dialog_analyzer.extract_services(messages)
    dialog_context = dialog_analyzer.extract_dialog_context(messages)

    # Рассчитываем стоимость если возможно
    cost_calculation = nil
    if car_info && car_info[:class] && required_services && required_services.any?
      cost_calculation = cost_calculator.calculate_cost(required_services, car_info[:class])
      @logger.debug "Cost calculation completed: #{cost_calculation.inspect}" if cost_calculation
    end

    # Создаем и обогащаем RequestDetector
    RequestDetector.new(@config, @logger).tap do |detector|
      detector.enrich_with(
        car_info: car_info,
        required_services: required_services,
        cost_calculation: cost_calculation,
        dialog_context: dialog_context
      )
    end
  rescue StandardError => e
    @logger.error "Error creating enriched RequestDetector: #{e.message}"
    # Возвращаем базовый RequestDetector в случае ошибки
    RequestDetector.new(@config, @logger)
  end
end
