# frozen_string_literal: true

require 'test_helper'
require_relative '../lib/ruby_llm_client'

class TestLLMClient < Minitest::Test
  def setup
    # Set required environment variables before creating config
    ENV['TELEGRAM_BOT_TOKEN'] = 'test_token'
    ENV['LLM_PROVIDER'] = 'openai'
    ENV['LLM_MODEL'] = 'gpt-3.5-turbo'

    @config = AppConfig.new
    @logger = Logger.new($stdout, level: Logger::ERROR)

    # Override paths for testing
    @config.system_prompt_path = './test/fixtures/system-prompt.md'
    @config.company_info_path = './test/fixtures/company-info.md'
    @config.price_list_path = './test/fixtures/price.csv'
    @config.welcome_message_path = './test/fixtures/welcome-message.md'
  end

  def teardown
    # Clean up environment variables
    ENV.delete('TELEGRAM_BOT_TOKEN')
    ENV.delete('LLM_PROVIDER')
    ENV.delete('LLM_MODEL')
  end

  def test_company_info_loading
    LLMClient.new(@config, @logger)

    # Проверяем, что информация о компании доступна через конфиг
    refute_nil @config.company_info
    refute_empty @config.company_info.strip
    assert_includes @config.company_info, 'Авто-Сервис Кузник'
    assert_includes @config.company_info, '+79022407000'
  end

  def test_system_prompt_with_company_info
    LLMClient.new(@config, @logger)

    # Проверяем, что системный промпт содержит информацию о компании
    refute_nil @config.system_prompt
    refute_empty @config.system_prompt.strip
    assert_includes @config.system_prompt, '[COMPANY_INFO]'
  end

  def test_build_combined_system_prompt
    client = LLMClient.new(@config, @logger)

    # Получаем комбинированный промпт через приватный метод
    combined_prompt = client.send(:build_combined_system_prompt)

    refute_nil combined_prompt
    refute_empty combined_prompt.strip

    # Проверяем, что плейсхолдер заменен на реальную информацию
    refute_includes combined_prompt, '[COMPANY_INFO]'
    assert_includes combined_prompt, 'Авто-Сервис Кузник'
    assert_includes combined_prompt, '+79022407000'

    # Проверяем, что прайс-лист также добавлен
    assert_includes combined_prompt, 'ПРАЙС-ЛИСТ'
  end

  def test_company_info_content_structure
    client = LLMClient.new(@config, @logger)

    combined_prompt = client.send(:build_combined_system_prompt)

    # Проверяем наличие ключевой информации о компании
    assert_includes combined_prompt, 'Авто-Сервис Кузник'
    assert_includes combined_prompt, 'ИП Никифоров'
    assert_includes combined_prompt, '+79022407000'
    assert_includes combined_prompt, 'Kuznikpaint@yandex.ru'
    assert_includes combined_prompt, 'г. Чебоксары, Ядринское ш.'
    assert_includes combined_prompt, 'yandex.ru/maps'
  end

  def test_combined_prompt_sections_order
    client = LLMClient.new(@config, @logger)

    combined_prompt = client.send(:build_combined_system_prompt)

    # Проверяем порядок секций в итоговом промпте
    lines = combined_prompt.split("\n")

    # Должна быть информация о компании перед прайс-листом
    company_info_index = lines.find_index { |line| line.include?('Авто-Сервис Кузник') }
    price_list_index = lines.find_index { |line| line.include?('ПРАЙС-ЛИСТ') }

    refute_nil company_info_index
    refute_nil price_list_index
    assert company_info_index < price_list_index, 'Company info should come before price list'
  end
end
