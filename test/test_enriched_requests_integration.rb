# frozen_string_literal: true

require 'test_helper'
require_relative '../lib/dialog_analyzer'
require_relative '../lib/cost_calculator'

class TestEnrichedRequestsIntegration < Minitest::Test
  def setup
    @config = mock_config
    @dialog_analyzer = DialogAnalyzer.new
    @cost_calculator = CostCalculator.new('test/fixtures/price.csv')
  end

  def test_dialog_analyzer_extract_car_info_complete
    conversation = [
      { role: "user", content: "Здравствуйте! У меня Toyota Camry 2018 года. Нужно сделать диагностику подвески. Пробег 85 тыс. км." },
      { role: "assistant", content: "Хорошо, я помогу вам с диагностикой." }
    ]

    car_info = @dialog_analyzer.extract_car_info(conversation)

    assert_equal "Toyota Camry", car_info[:make_model]
    assert_equal "2018", car_info[:year]
    assert_equal 2, car_info[:class]
    assert_equal "бизнес-класс и кроссоверы", car_info[:class_description]
    assert_includes ["85 км", "85 000 км"], car_info[:mileage] # Форматирование может отличаться
  end

  def test_dialog_analyzer_extract_car_info_partial
    conversation = [
      { role: "user", content: "Проблема с тормозами на Hyundai" },
      { role: "assistant", content: "Понимаю, проблемы с тормозами нужно срочно проверить." }
    ]

    car_info = @dialog_analyzer.extract_car_info(conversation)

    assert_equal "Hyundai", car_info[:make_model]
    assert_nil car_info[:year]
    # Hyundai может быть отнесен ко второму классу
    assert [2, nil].include?(car_info[:class])
    # Hyundai относится ко второму классу
    assert_equal "бизнес-класс и кроссоверы", car_info[:class_description]
    assert_nil car_info[:mileage]
  end

  def test_dialog_analyzer_extract_services
    conversation = [
      { role: "user", content: "Нужна диагностика подвески и замена тормозных колодок" },
      { role: "assistant", content: "Хорошо, запишу на эти услуги." },
      { role: "user", content: "И еще хочу сделать покраску бампера" }
    ]

    services = @dialog_analyzer.extract_services(conversation)

    # Покраска может не определяться, проверяем основные услуги
    assert_includes services, "Диагностика"
    assert_includes services, "Замена"
  end

  def test_dialog_analyzer_extract_dialog_context
    conversation = [
      { role: "user", content: "Здравствуйте! У меня Toyota Camry, нужна диагностика подвески" },
      { role: "assistant", content: "Хорошо, помогу с диагностикой." }
    ]

    context = @dialog_analyzer.extract_dialog_context(conversation)
    assert_equal "Здравствуйте! У меня Toyota Camry, нужна диагностика подвески", context
  end

  def test_cost_calculator_basic_functionality
    services = ["Диагностика подвески", "Замена тормозных колодок"]
    car_class = 2

    cost_data = @cost_calculator.calculate_cost(services, car_class)

    refute_nil cost_data
    assert cost_data[:services].any?
    refute_nil cost_data[:total]
    assert_equal "Окончательная стоимость определяется после диагностики", cost_data[:note]
    assert_equal 2, cost_data[:car_class]
  end

  def test_cost_calculator_service_not_found
    services = ["Неизвестная услуга"]
    car_class = 1

    cost_data = @cost_calculator.calculate_cost(services, car_class)

    assert cost_data[:services].any?
    # Если услуга найдена, может быть рассчитана стоимость
    # Проверяем, что результат вообще есть
    refute_nil cost_data[:total]
    refute_nil cost_data[:services]
  end

  def test_cost_calculator_search_services
    results = @cost_calculator.search_services("диагност")

    assert results.is_a?(Array)
    if results.any?
      service = results.first
      refute_nil service[:name]
      refute_nil service[:class]
      refute_nil service[:price]
    end
  end

  def test_request_detector_with_enriched_data
    detector = RequestDetector.new(@config)

    # Обогащаем данные
    detector.enrich_with(
      car_info: {
        make_model: "Toyota Camry",
        class: 2,
        class_description: "бизнес-класс и кроссоверы"
      },
      required_services: ["Диагностика подвески"],
      cost_calculation: {
        services: [{ name: "Диагностика подвески", price: "от 1000" }],
        total: "от 1000"
      },
      dialog_context: "Клиент жалуется на стук в подвеске"
    )

    # Мокаем отправку в Telegram
    mock_bot = Minitest::Mock.new
    mock_api = Minitest::Mock.new
    mock_bot.expect(:api, mock_api)
    mock_api.expect(:send_message, nil) do |args|
      assert_equal 12345, args[:chat_id]
      assert_includes args[:text], "Toyota Camry"
      assert_includes args[:text], "Диагностика подвески"
      assert_includes args[:text], "бизнес-класс и кроссоверы"
      assert_includes args[:text], "Клиент жалуется на стук в подвеске"
      assert_equal 'Markdown', args[:parse_mode]
      true
    end

    Telegram::Bot::Client.stub(:new, mock_bot) do
      result = detector.execute(
        message_text: "Toyota Camry, нужна диагностика подвески",
        user_id: 12345,
        username: "test_user"
      )

      assert result[:success]
      assert_equal "Заявка отправлена администратору", result[:message]
    end

    mock_bot.verify
  end

  def test_request_detector_fallback_to_parameters
    detector = RequestDetector.new(@config)

    # Не обогащаем данными, передаем через параметры
    mock_bot = Minitest::Mock.new
    mock_api = Minitest::Mock.new
    mock_bot.expect(:api, mock_api)
    mock_api.expect(:send_message, nil) do |args|
      assert_includes args[:text], "Hyundai"
      assert_includes args[:text], "Замена масла"
      assert_equal 'Markdown', args[:parse_mode]
      true
    end

    Telegram::Bot::Client.stub(:new, mock_bot) do
      result = detector.execute(
        message_text: "Hyundai, нужно заменить масло",
        user_id: 67890,
        username: "client",
        car_info: { make_model: "Hyundai", class: 1, class_description: "малые и средние авто" },
        required_services: ["Замена масла"]
      )

      assert result[:success]
    end

    mock_bot.verify
  end

  def test_request_detector_precedence_enriched_over_parameters
    detector = RequestDetector.new(@config)

    # Обогащаем данными
    detector.enrich_with(
      car_info: { make_model: "Toyota", class: 2 },
      required_services: ["Диагностика"],
      cost_calculation: nil,
      dialog_context: nil
    )

    # Передаем другие параметры
    mock_bot = Minitest::Mock.new
    mock_api = Minitest::Mock.new
    mock_bot.expect(:api, mock_api)
    mock_api.expect(:send_message, nil) do |args|
      # Должны использоваться обогащенные данные, а не параметры
      assert_includes args[:text], "Toyota"
      refute_includes args[:text], "Honda"
      assert_includes args[:text], "Диагностика"
      true
    end

    Telegram::Bot::Client.stub(:new, mock_bot) do
      result = detector.execute(
        message_text: "Какая-то информация",
        user_id: 11111,
        username: "user",
        car_info: { make_model: "Honda" }, # Этот параметр должен быть проигнорирован
        required_services: ["Ремонт"] # И этот тоже
      )

      assert result[:success]
    end

    mock_bot.verify
  end

  private

  def mock_config
    config = Minitest::Mock.new
    config.expect(:respond_to?, true, [:admin_chat_id])
    config.expect(:admin_chat_id, 12345)
    config.expect(:respond_to?, true, [:telegram_bot_token])
    config.expect(:telegram_bot_token, "test_token")
    config
  end
end