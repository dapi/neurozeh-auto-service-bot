# frozen_string_literal: true

require 'anthropic'
require 'logger'
require 'net/http'
require 'uri'
require 'openssl'

class ClaudeClient
  MAX_RETRIES = 1

  def initialize(config, logger = Logger.new($stdout))
    @config = config
    @logger = logger

    # anyway_config уже валидировал системный промпт, но загружаем его
    @system_prompt = load_system_prompt

    # Загружаем и форматируем прайс-лист (anyway_config проверил существование файла)
    @price_list = load_and_format_price_list

    # Инициализируем Anthropic клиент
    @client = Anthropic::Client.new()

    @logger.info 'ClaudeClient initialized with anthropic gem, system prompt and price list'
  end

  def send_message(messages)
    @logger.info "Sending message to Claude API with #{messages.length} messages"

    # Комбинируем системный промпт с отформатированным прайс-листом
    combined_system_prompt = "#{@system_prompt}\n\n---\n\n## ПРАЙС-ЛИСТ\n\n#{@price_list}"

    retries = 0
    begin
      response = @client.messages.create(
        model: @config.anthropic_model,
        max_tokens: 1500, # Увеличиваем для учета контекста прайс-листа
        system: combined_system_prompt,
        messages: messages
      )

      # Извлекаем текст из ответа anthropic gem
      content = response.content.first
      if content.is_a?(Anthropic::Models::TextBlock)
        content.text
      else
        @logger.error "Unexpected response content type: #{content.class}"
        raise 'Unexpected response format from Claude API'
      end
    rescue Anthropic::Errors::AuthenticationError => e
      @logger.error "Authentication error: #{e.message}"
      raise e
    rescue Anthropic::Errors::RateLimitError => e
      @logger.error "Rate limit error: #{e.message}"
      raise e
    rescue Anthropic::Errors::APIError => e
      @logger.error "Claude API error: #{e.message}"
      @logger.error "Status: #{e.status}" if e.status
      @logger.error "Body: #{e.body}" if e.body
      raise e
    rescue StandardError => e
      retries += 1
      if retries <= MAX_RETRIES
        @logger.warn "Error sending message to Claude API, retrying (#{retries}/#{MAX_RETRIES}): #{e.message}"
        @logger.warn "Error class: #{e.class}"
        @logger.warn "Error backtrace: #{e.backtrace&.first(5)&.join(', ')}"
        sleep(1) # Wait before retrying
        retry
      else
        @logger.error "Failed to send message to Claude API after #{MAX_RETRIES} retries: #{e.message}"
        @logger.error "Final error class: #{e.class}"
        @logger.error "Final error backtrace: #{e.backtrace&.first(10)&.join("\n")}"
        @logger.error "API configuration - Model: #{@config.anthropic_model}, Base URL: #{@config.anthropic_base_url}"
        @logger.error "Token present: #{@config.anthropic_auth_token && !@config.anthropic_auth_token.empty? ? 'YES' : 'NO'}"
        raise e
      end
    end
  end

  private

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
