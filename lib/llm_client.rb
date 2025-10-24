# frozen_string_literal: true

require 'ruby_llm'
require 'logger'
require_relative 'request_detector'

class LLMClient
  MAX_RETRIES = 1

  def initialize(config, logger = Logger.new($stdout))
    @config = config
    @logger = logger
    @logger.info 'LLMClient initialized with system prompt and price list'
  end

  def send_message(messages, user_info = nil)
    @logger.info "=== LLM CLIENT SEND_MESSAGE START ==="
    @logger.info "Sending message to LLM with #{messages.length} messages"
    @logger.info "User info: #{user_info.inspect}"

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
        # RequestDetector автоматически получит нужные параметры от AI модели
        request_detector = RequestDetector.new(@config, @logger)
        chat.with_tool(request_detector)

        # Логирование вызовов tool
        chat.on_tool_call do |tool_call|
          @logger.info "🔔 REQUEST DETECTED: AI calling tool: #{tool_call.name} for user #{tool_call.arguments[:user_id]}"
          @logger.debug "Tool arguments: #{tool_call.arguments}"
        end

        chat.on_tool_result do |result|
          if result[:success]
            @logger.info "✅ REQUEST SENT: #{result[:request_type]} for user #{user_info[:id]}"
          elsif result[:error]
            @logger.error "❌ REQUEST ERROR: #{result[:error]}"
          else
            @logger.warn "❌ REQUEST REJECTED: #{result[:reason]}"
          end
        end
      end

      # Получаем последнее сообщение пользователя
      last_message = messages.last
      raise ArgumentError, 'No messages to send' unless last_message
      raise ArgumentError, 'Last message is not from user' unless last_message[:role] == 'user'

      @logger.debug "Last message content: #{last_message[:content][0..100]}..."

      # Добавляем контекст диалога в сообщение для AI, чтобы он мог использовать RequestDetector с нужными параметрами
      if user_info && @config.admin_chat_id && messages.length > 1
        context_messages = messages[0..-2]
        if context_messages.any?
          conversation_context = context_messages.map { |msg| "#{msg[:role]}: #{msg[:content]}" }.join("\n\n")
          # Добавляем контекст в начало сообщения, чтобы AI мог анализировать всю беседу
          contextual_message = "Контекст диалога:\n#{conversation_context}\n\nТекущее сообщение пользователя: #{last_message[:content]}"
          last_message = { role: 'user', content: contextual_message }
          @logger.debug "Enhanced message with conversation context for RequestDetector"
        end
      end

      # Отправляем сообщение и получаем ответ
      @logger.info "=== SENDING TO RUBYLLM API ==="
      @logger.info "Using provider: #{@config.llm_provider}, model: #{@config.llm_model}"
      @logger.info "Last message: #{last_message[:content][0..100]}..."
      @logger.debug "Full last message: #{last_message.inspect}"

      response = chat.ask(last_message[:content])

      @logger.info "=== RECEIVED RESPONSE FROM RUBYLLM API ==="
      @logger.info "Response type: #{response.class}"
      @logger.info "Response content length: #{response.content&.length || 0}"
      @logger.debug "Response object: #{response.inspect}"

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
