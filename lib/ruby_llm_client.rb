# frozen_string_literal: true

require 'ruby_llm'
require 'logger'

class RubyLLMClient
  MAX_RETRIES = 1

  def initialize(config, logger = Logger.new($stdout))
    @config = config
    @logger = logger

    # anyway_config уже валидировал системный промпт, но загружаем его
    @system_prompt = load_system_prompt

    # Загружаем и форматируем прайс-лист (anyway_config проверил существование файла)
    @price_list = load_and_format_price_list

    # Настраиваем RubyLLM
    configure_ruby_llm

    # Инициализируем чат
    @chat = RubyLLM.chat(model: @config.ruby_llm_model || @config.anthropic_model)

    @logger.info 'RubyLLMClient initialized with ruby_llm gem, system prompt and price list'
  end

  def send_message(messages)
    @logger.info "Sending message to RubyLLM with #{messages.length} messages"

    # Комбинируем системный промпт с отформатированным прайс-листом
    combined_system_prompt = "#{@system_prompt}\n\n---\n\n## ПРАЙС-ЛИСТ\n\n#{@price_list}"

    retries = 0
    begin
      # Выбираем чат: кастомный или стандартный
      chat = get_chat_for_request

      # Устанавливаем системные инструкции
      chat.with_instructions(combined_system_prompt, replace: true)

      # Получаем последнее сообщение пользователя
      last_message = messages.last
      raise ArgumentError, 'No messages to send' unless last_message
      raise ArgumentError, 'Last message is not from user' unless last_message[:role] == 'user'

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
        @logger.warn "Error sending message to RubyLLM, retrying (#{retries}/#{MAX_RETRIES}): #{e.message}"
        @logger.warn "Error class: #{e.class}"
        @logger.warn "Error backtrace: #{e.backtrace&.first(5)&.join(', ')}"
        sleep(1) # Wait before retrying
        retry
      else
        @logger.error "Failed to send message to RubyLLM after #{MAX_RETRIES} retries: #{e.message}"
        @logger.error "Final error class: #{e.class}"
        @logger.error "Final error backtrace: #{e.backtrace&.first(10)&.join("\n")}"
        @logger.error "API configuration - Model: #{@config.ruby_llm_model || @config.anthropic_model}"
        @logger.error "Token present: #{@config.anthropic_auth_token && !@config.anthropic_auth_token.empty? ? 'YES' : 'NO'}"
        raise e
      end
    end
  end

  private

  def get_chat_for_request
    # Если у нас есть кастомный контекст, используем его
    return get_custom_chat if @custom_context

    # Иначе используем стандартный чат
    @chat
  end

  def get_custom_chat
    # Если мы определили, что нужно использовать OpenAI формат
    if @use_openai_format
      @custom_context.chat(model: @config.ruby_llm_model || @config.anthropic_model, provider: :openai)
    else
      # Используем Anthropic формат с кастомным контекстом
      @custom_context.chat(model: @config.ruby_llm_model || @config.anthropic_model, provider: :anthropic)
    end
  end

  def configure_ruby_llm
    RubyLLM.configure do |config|
      # Используем существующий токен anthropic как токен для Anthropic провайдера в ruby_llm
      config.anthropic_api_key = @config.anthropic_auth_token

      # Устанавливаем таймауты и retry настройки
      config.request_timeout = 120
      config.max_retries = MAX_RETRIES
    end

    # Для кастомного API URL используем отдельный контекст
    return unless @config.anthropic_base_url && @config.anthropic_base_url != 'https://api.anthropic.com'

    @logger.info "Using custom base URL: #{@config.anthropic_base_url}"
    configure_custom_endpoint
  end

  def configure_custom_endpoint
    # Создаем кастомный контекст для работы с нестандартным endpoint
    @custom_context = RubyLLM.context do |config|
      config.anthropic_api_key = @config.anthropic_auth_token
      config.request_timeout = 120
      config.max_retries = MAX_RETRIES

      # Для кастомных endpoints может потребоваться специальная конфигурация
      # В ruby_llm это можно сделать через переопределение HTTP клиента
      if @config.anthropic_base_url.include?('api.z.ai')
        # Специальная обработка для api.z.ai
        configure_z_ai_endpoint(config)
      end
    end
  end

  def configure_z_ai_endpoint(config)
    # Для api.z.ai используем OpenAI-совCompatible формат, если доступен
    # Иначе используем стандартный Anthropic-формат с переопределением URL

    # Сначала проверяем, задан ли явный openai_api_base в конфиге
    if @config.openai_api_base && !@config.openai_api_base.empty?
      @logger.info "Using explicit OpenAI-compatible endpoint from config: #{@config.openai_api_base}"
      config.openai_api_key = @config.anthropic_auth_token
      config.openai_api_base = @config.openai_api_base
      @use_openai_format = true
      return
    end

    # Если явный endpoint не указан, пытаемся автоматически определить
    # Проверим, есть ли OpenAI-совместимый endpoint
    z_ai_openai_url = @config.anthropic_base_url.gsub('/api/anthropic', '/v1')

    begin
      # Простая проверка доступности endpoint
      require 'net/http'
      require 'uri'

      uri = URI(z_ai_openai_url)
      response = Net::HTTP.get_response(uri)

      if response.code == '200'
        @logger.info "Using auto-detected OpenAI-compatible endpoint: #{z_ai_openai_url}"
        config.openai_api_key = @config.anthropic_auth_token
        config.openai_api_base = z_ai_openai_url
        @use_openai_format = true
      end
    rescue StandardError => e
      @logger.warn "OpenAI-compatible endpoint not available, using Anthropic format: #{e.message}"
    end
  end

  def load_system_prompt
    # anyway_config уже проверил существование файла, но добавляем дополнительную защиту
    path = @config.system_prompt_path
    content = File.read(path, encoding: 'UTF-8')

    if content.strip.empty?
      @logger.error "System prompt file is empty: #{path}"
      raise "System prompt file is empty: #{path}"
    end

    content
  rescue StandardError => e
    @logger.error "Failed to load system prompt: #{e.message}"
    raise e
  end

  def load_and_format_price_list
    price_list_path = @config.price_list_path

    # anyway_config уже проверил существование и читаемость файла
    content = File.read(price_list_path, encoding: 'UTF-8')

    if content.strip.empty?
      @logger.error "Price list file is empty: #{price_list_path}"
      return '❌ Прайс-лист пуст. Пожалуйста, обратитесь позже.'
    end

    format_price_list_for_claude(content)
  rescue StandardError => e
    @logger.error "Failed to load price list: #{e.message}"
    '❌ Прайс-лист временно недоступен. Пожалуйста, обратитесь позже.'
  end

  def format_price_list_for_claude(csv_content)
    # Убираем лишние пустые строки и форматируем для лучшего понимания
    lines = csv_content.split("\n").reject(&:empty?)

    formatted = "📋 АКТУАЛЬНЫЙ ПРАЙС-ЛИСТ АВТОСЕРВИСА 'КУЗНИК'\n\n"

    lines.each do |line|
      next if line.strip.empty?

      # Добавляем эмодзи для визуального выделения категорий и заголовков
      formatted += if line.match?(/^[A-ZА-ЯЁ]+/i) || line.include?('Класс') || line.include?('класс')
                     "📋 #{line}\n"
                   else
                     "#{line}\n"
                   end
    end

    # Добавляем важное примечание
    formatted += "\n#{'─' * 50}\n"
    formatted += "⚠️ ВАЖНОЕ ПРИМЕЧАНИЕ:\n"
    formatted += "• Все цены указаны ЗА ЭЛЕМЕНТ без учета дополнительных работ\n"
    formatted += "• Дополнительные работы оплачиваются отдельно по этому прайс-листу\n"
    formatted += "• Окончательная стоимость определяется после диагностики\n"
    formatted += "#{'─' * 50}\n"

    formatted
  end
end
