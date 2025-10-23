require 'test_helper'

class TestClaudeClientPriceList < Minitest::Test
  def setup
    # Создаем тестовую конфигурацию и файлы
    File.write('./test/fixtures/test_system_prompt.md', 'test prompt')
    File.write('./test/fixtures/test_price_list.csv', "Прайс лист\nПОКРАСКА\nКапот,1000,2000,3000")

    @config = AppConfig.new(
      anthropic_auth_token: 'test_token',
      telegram_bot_token: 'test_token',
      system_prompt_path: './test/fixtures/test_system_prompt.md',
      price_list_path: './test/fixtures/test_price_list.csv'
    )

    # Создаем mock logger для тестов
    @mock_logger = Minitest::Mock.new
    @mock_logger.expect(:info, nil, ["ClaudeClient initialized with system prompt and price list"])

    @client = ClaudeClient.new(@config, @mock_logger)
  end

  def teardown
    # Удаляем тестовые файлы
    File.delete('./test/fixtures/test_system_prompt.md') if File.exist?('./test/fixtures/test_system_prompt.md')
    File.delete('./test/fixtures/test_price_list.csv') if File.exist?('./test/fixtures/test_price_list.csv')

    # Verify mock expectations
    @mock_logger.verify if @mock_logger
  end

  def test_load_price_list_success
    price_list = @client.instance_variable_get(:@price_list)
    refute_nil price_list
    assert_includes price_list, 'ПОКРАСКА'
    assert_includes price_list, '📋 АКТУАЛЬНЫЙ ПРАЙС-ЛИСТ'
    assert_includes price_list, '🎨'
  end

  def test_price_list_formatting
    price_list = @client.instance_variable_get(:@price_list)
    assert_includes price_list, '⚠️ ВАЖНОЕ ПРИМЕЧАНИЕ'
    assert_includes price_list, 'Все цены указаны ЗА ЭЛЕМЕНТ'
  end

  def test_empty_price_list_handling
    File.write('./test/fixtures/empty_price_list.csv', '')

    config = AppConfig.new(
      anthropic_auth_token: 'test_token',
      telegram_bot_token: 'test_token',
      system_prompt_path: './test/fixtures/test_system_prompt.md',
      price_list_path: './test/fixtures/empty_price_list.csv'
    )

    mock_logger = Minitest::Mock.new
    mock_logger.expect(:info, nil, ["ClaudeClient initialized with system prompt and price list"])
    mock_logger.expect(:error, nil, ["Price list file is empty: ./test/fixtures/empty_price_list.csv"])

    client = ClaudeClient.new(config, mock_logger)

    price_list = client.instance_variable_get(:@price_list)
    assert_includes price_list, 'Прайс-лист пуст'

    mock_logger.verify
    File.delete('./test/fixtures/empty_price_list.csv')
  end

  def test_combined_system_prompt_generation
    # Проверяем, что системный промпт комбинируется с прайс-листом
    price_list = @client.instance_variable_get(:@price_list)
    system_prompt = @client.instance_variable_get(:@system_prompt)

    refute_nil system_prompt
    refute_nil price_list
    assert system_prompt.length > 0
    assert price_list.length > 0

    # Проверяем наличие важных компонентов в прайс-листе
    assert_includes price_list, '📋 АКТУАЛЬНЫЙ ПРАЙС-ЛИСТ'
    assert_includes price_list, 'ПОКРАСКА'
  end
end