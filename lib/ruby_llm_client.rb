# frozen_string_literal: true

require 'ruby_llm'
require 'logger'

class LLMClient
  MAX_RETRIES = 1

  def initialize(config, logger = Logger.new($stdout))
    @config = config
    @logger = logger
    @logger.info 'LLMClient initialized with system prompt and price list'
  end

  def send_message(messages)
    @logger.info "Sending message to RubyLLM with #{messages.length} messages"

    # Комбинируем системный промпт с информацией о компании и прайс-листом
    combined_system_prompt = build_combined_system_prompt

    retries = 0
    begin
      @logger.info "LLMClient model: #{@config.llm_model}, provider: #{@config.llm_provider}"
      # Выбираем чат: кастомный или стандартный
      chat = RubyLLM.chat model: @config.llm_model, provider: @config.llm_provider.to_sym, assume_model_exists: true

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
end
