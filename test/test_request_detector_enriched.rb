# frozen_string_literal: true

require 'test_helper'

class TestRequestDetectorEnriched < Minitest::Test
  def setup
    @config = mock_config
    @detector = RequestDetector.new(@config)
  end

  def test_format_car_info_complete
    car_info = {
      make_model: "Toyota Camry",
      year: "2018",
      class: 2,
      class_description: "бизнес-класс и кроссоверы",
      mileage: "85 000 км"
    }

    result = @detector.send(:format_car_info, car_info)

    assert_includes result, "Toyota Camry"
    assert_includes result, "2018"
    assert_includes result, "бизнес-класс и кроссоверы"
    assert_includes result, "85 000 км"
    assert_includes result, "🚗 **Информация об автомобиле:**"
  end

  def test_format_car_info_partial
    car_info = {
      make_model: "Hyundai",
      class: nil
    }

    result = @detector.send(:format_car_info, car_info)

    assert_includes result, "Hyundai"
    assert_includes result, "требуется уточнение"
    refute_includes result, "Год выпуска"
    refute_includes result, "Пробег"
  end

  def test_format_car_info_empty
    result = @detector.send(:format_car_info, nil)
    assert_equal "", result
  end

  def test_format_required_services_multiple
    services = [
      "Диагностика подвески",
      "Замена передних тормозных колодок",
      "Проверка амортизаторов"
    ]

    result = @detector.send(:format_required_services, services)

    assert_includes result, "🔧 **Необходимые работы:**"
    assert_includes result, "1. Диагностика подвески"
    assert_includes result, "2. Замена передних тормозных колодок"
    assert_includes result, "3. Проверка амортизаторов"
  end

  def test_format_required_services_single
    services = ["Диагностика"]

    result = @detector.send(:format_required_services, services)

    assert_includes result, "🔧 **Необходимые работы:**"
    assert_includes result, "1. Диагностика"
  end

  def test_format_required_services_empty
    result = @detector.send(:format_required_services, nil)
    assert_equal "", result

    result = @detector.send(:format_required_services, [])
    assert_equal "", result
  end

  def test_format_cost_calculation_complete
    cost_data = {
      services: [
        { name: "Диагностика подвески", price: "2 500 руб." },
        { name: "Замена тормозных колодок (2 класс)", price: "4 000 руб." }
      ],
      total: "6 500 руб.",
      note: "Окончательная стоимость определяется после диагностики"
    }

    result = @detector.send(:format_cost_calculation, cost_data)

    assert_includes result, "💰 **Расчет стоимости:**"
    assert_includes result, "Диагностика подвески: 2 500 руб."
    assert_includes result, "Замена тормозных колодок (2 класс): 4 000 руб."
    assert_includes result, "• **Итого базовая стоимость:** 6 500 руб."
    assert_includes result, "Окончательная стоимость определяется после диагностики"
  end

  def test_format_cost_calculation_without_services
    cost_data = {
      services: [],
      total: nil,
      note: "Требуется уточнение объема работ"
    }

    result = @detector.send(:format_cost_calculation, cost_data)

    assert_includes result, "💰 **Расчет стоимости:**"
    assert_includes result, "Требуется уточнение объема работ"
    refute_includes result, "Итого базовая стоимость"
  end

  def test_format_cost_calculation_empty
    result = @detector.send(:format_cost_calculation, nil)
    assert_equal "", result
  end

  def test_format_cost_calculation_default_note
    cost_data = {
      services: [
        { name: "Диагностика", price: "от 1000" }
      ],
      total: "от 1000"
    }

    result = @detector.send(:format_cost_calculation, cost_data)

    assert_includes result, "Окончательная стоимость определяется после диагностики"
  end

  def test_format_dialog_context
    context = "Пользователь интересуется диагностикой подвески, замечает стук при проезде неровностей."

    result = @detector.send(:format_dialog_context, context)

    assert_includes result, "💬 **Контекст диалога:**"
    assert_includes result, context
  end

  def test_format_dialog_context_empty
    result = @detector.send(:format_dialog_context, nil)
    assert_equal "", result
  end

  def test_format_action_buttons
    user_id = 12345

    result = @detector.send(:format_action_buttons, user_id)

    assert_includes result, "🔗 **Действия:**"
    assert_includes result, "/answer_12345"
    assert_includes result, "/close_12345"
  end

  def test_format_basic_info_with_username
    request_info = {
      original_text: "Здравствуйте! Нужно диагностику подвески",
      matched_patterns: ["service:диагностика", "car_part:подвеска"]
    }
    user_id = 12345
    username = "test_user"
    first_name = "Test"

    result = @detector.send(:format_basic_info, request_info, user_id, username, first_name)

    assert_includes result, "🔔 **НОВАЯ ЗАЯВКА**"
    assert_includes result, "[@test_user](https://t.me/test_user)"
    assert_includes result, "`12345`"
    assert_includes result, "Здравствуйте! Нужно диагностику подвески"
    assert_includes result, "🔍 **Распознанные паттерны:**"
    assert_includes result, "service: `диагностика`"
  end

  def test_format_basic_info_without_username
    request_info = {
      original_text: "Хочу записаться на ТО"
    }
    user_id = 67890
    username = nil
    first_name = "Иван"

    result = @detector.send(:format_basic_info, request_info, user_id, username, first_name)

    assert_includes result, "Иван"
    assert_includes result, "`67890`"
    refute_includes result, "@"
  end

  def test_format_admin_notification_enriched
    request_info = {
      original_text: "Toyota Camry, нужна диагностика подвески",
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
    }
    user_id = 11111
    username = "client"
    first_name = "Client"

    result = @detector.send(:format_admin_notification, request_info, user_id, username, first_name)

    assert_includes result, "🚗 **Информация об автомобиле:**"
    assert_includes result, "Toyota Camry"
    assert_includes result, "бизнес-класс и кроссоверы"
    assert_includes result, "🔧 **Необходимые работы:**"
    assert_includes result, "Диагностика подвески"
    assert_includes result, "💰 **Расчет стоимости:**"
    assert_includes result, "💬 **Контекст диалога:**"
    assert_includes result, "Клиент жалуется на стук в подвеске"
    assert_includes result, "🔗 **Действия:**"
    assert_includes result, "/answer_11111"
  end

  def test_format_admin_notification_minimal
    request_info = {
      original_text: "Хочу на диагностику"
    }
    user_id = 22222

    result = @detector.send(:format_admin_notification, request_info, user_id, nil, nil)

    # Должна быть базовая информация
    assert_includes result, "🔔 **НОВАЯ ЗАЯВКА**"
    assert_includes result, "User#22222"
    assert_includes result, "Хочу на диагностику"

    # Не должно быть обогащенной информации
    refute_includes result, "🚗 **Информация об автомобиле:**"
    refute_includes result, "🔧 **Необходимые работы:**"
    refute_includes result, "💰 **Расчет стоимости:**"
    refute_includes result, "💬 **Контекст диалога:**"
  end

  def test_execute_with_enriched_data
    _ = {
      original_text: "Toyota Camry, нужно диагностику",
      car_info: { make_model: "Toyota Camry", class: 2 },
      required_services: ["Диагностика"],
      cost_calculation: nil,
      dialog_context: nil
    }

    # Мокаем отправку в Telegram
    mock_bot = Minitest::Mock.new
    mock_api = Minitest::Mock.new
    mock_bot.expect(:api, mock_api)
    mock_api.expect(:send_message, nil) do |args|
      assert_equal 12345, args[:chat_id]
      assert_includes args[:text], "Toyota Camry"
      assert_includes args[:text], "Диагностика"
      assert_equal 'Markdown', args[:parse_mode]
      true
    end

    Telegram::Bot::Client.stub(:new, mock_bot) do
      result = @detector.execute(
        message_text: "Toyota Camry, нужно диагностику",
        user_id: 12345,
        username: "test_user",
        car_info: { make_model: "Toyota Camry", class: 2 },
        required_services: ["Диагностика"]
      )

      assert result[:success]
      assert_equal "Заявка отправлена администратору", result[:message]
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