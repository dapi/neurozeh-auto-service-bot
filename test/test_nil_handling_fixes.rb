# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../lib/request_detector'
require_relative '../lib/dialog_analyzer'
require_relative '../lib/cost_calculator'

class TestNilHandlingFixes < Minitest::Test
  def setup
    @config = Minitest::Mock.new
    @config.expect :admin_chat_id, 123456789
    @config.expect :telegram_bot_token, 'test_token'

    @logger = Logger.new(IO::NULL)
  end

  # Test RequestDetector with nil and empty data
  def test_request_detector_with_nil_services
    request_detector = RequestDetector.new(@config, @logger)

    # Test with nil services
    request_info = {
      confidence: 1.0,
      original_text: 'Test message',
      car_info: {},
      required_services: nil,  # This should not cause nil.any? error
      cost_calculation: {},
      dialog_context: ''
    }

    notification = request_detector.send(:format_required_services, request_info[:required_services])
    assert_empty notification, "Should return empty string for nil services"
  end

  def test_request_detector_with_empty_services
    request_detector = RequestDetector.new(@config, @logger)

    # Test with empty services array
    request_info = {
      confidence: 1.0,
      original_text: 'Test message',
      car_info: {},
      required_services: [],  # This should not show the section
      cost_calculation: {},
      dialog_context: ''
    }

    notification = request_detector.send(:format_required_services, request_info[:required_services])
    assert_empty notification, "Should return empty string for empty services"
  end

  def test_request_detector_with_nil_cost_calculation
    request_detector = RequestDetector.new(@config, @logger)

    # Test with nil cost calculation
    request_info = {
      confidence: 1.0,
      original_text: 'Test message',
      car_info: {},
      required_services: ['Диагностика'],
      cost_calculation: nil,  # This should not cause nil.any? error
      dialog_context: ''
    }

    notification = request_detector.send(:format_cost_calculation, request_info[:cost_calculation])
    assert_empty notification, "Should return empty string for nil cost calculation"
  end

  def test_request_detector_with_empty_cost_calculation
    request_detector = RequestDetector.new(@config, @logger)

    # Test with empty cost calculation
    request_info = {
      confidence: 1.0,
      original_text: 'Test message',
      car_info: {},
      required_services: ['Диагностика'],
      cost_calculation: {},  # This should not show the section
      dialog_context: ''
    }

    notification = request_detector.send(:format_cost_calculation, request_info[:cost_calculation])
    assert_empty notification, "Should return empty string for empty cost calculation"
  end

  def test_request_detector_with_nil_car_info
    request_detector = RequestDetector.new(@config, @logger)

    # Test with nil car info
    request_info = {
      confidence: 1.0,
      original_text: 'Test message',
      car_info: nil,  # This should not cause errors
      required_services: ['Диагностика'],
      cost_calculation: {},
      dialog_context: ''
    }

    notification = request_detector.send(:format_car_info, request_info[:car_info])
    assert_empty notification, "Should return empty string for nil car info"
  end

  def test_request_detector_with_empty_car_info
    request_detector = RequestDetector.new(@config, @logger)

    # Test with empty car info
    request_info = {
      confidence: 1.0,
      original_text: 'Test message',
      car_info: {},  # This should not show the section
      required_services: ['Диагностика'],
      cost_calculation: {},
      dialog_context: ''
    }

    notification = request_detector.send(:format_car_info, request_info[:car_info])
    assert_empty notification, "Should return empty string for empty car info"
  end

  def test_request_detector_with_nil_dialog_context
    request_detector = RequestDetector.new(@config, @logger)

    # Test with nil dialog context
    request_info = {
      confidence: 1.0,
      original_text: 'Test message',
      car_info: {},
      required_services: ['Диагностика'],
      cost_calculation: {},
      dialog_context: nil  # This should not cause errors
    }

    notification = request_detector.send(:format_dialog_context, request_info[:dialog_context])
    assert_empty notification, "Should return empty string for nil dialog context"
  end

  def test_request_detector_with_empty_dialog_context
    request_detector = RequestDetector.new(@config, @logger)

    # Test with empty dialog context
    request_info = {
      confidence: 1.0,
      original_text: 'Test message',
      car_info: {},
      required_services: ['Диагностика'],
      cost_calculation: {},
      dialog_context: '   '  # Whitespace only should not show the section
    }

    notification = request_detector.send(:format_dialog_context, request_info[:dialog_context])
    assert_empty notification, "Should return empty string for whitespace-only dialog context"
  end

  # Test DialogAnalyzer with nil inputs
  def test_dialog_analyzer_extract_services_with_nil_messages
    dialog_analyzer = DialogAnalyzer.new(@logger)

    # Test with nil messages - should not raise error
    services = dialog_analyzer.extract_services(nil)
    assert_equal [], services, "Should return empty array for nil messages"
  end

  def test_dialog_analyzer_extract_services_with_empty_messages
    dialog_analyzer = DialogAnalyzer.new(@logger)

    # Test with empty messages array
    services = dialog_analyzer.extract_services([])
    assert_equal [], services, "Should return empty array for empty messages"
  end

  def test_dialog_analyzer_extract_car_info_with_nil_make_model
    dialog_analyzer = DialogAnalyzer.new(@logger)

    # Test with nil make_model - should not raise error
    messages = [{ role: 'user', content: 'нужен ремонт' }]
    car_info = dialog_analyzer.extract_car_info(messages)
    assert_nil car_info[:class], "Should return nil class for nil make_model"
  end

  # Test CostCalculator with nil inputs
  def test_cost_calculator_with_nil_services
    cost_calculator = CostCalculator.new('test_price_list.csv', @logger)

    # Mock the price list reading to avoid file dependency
    cost_calculator.instance_variable_set(:@price_list, [])

    # Test with nil services - should not raise error
    result = cost_calculator.calculate_cost(nil, 1)
    assert_nil result, "Should return nil for nil services"
  end

  def test_cost_calculator_with_empty_services
    cost_calculator = CostCalculator.new('test_price_list.csv', @logger)

    # Mock the price list reading to avoid file dependency
    cost_calculator.instance_variable_set(:@price_list, [])

    # Test with empty services array
    result = cost_calculator.calculate_cost([], 1)
    assert_nil result, "Should return nil for empty services"
  end

  def test_cost_calculator_with_nil_car_class
    cost_calculator = CostCalculator.new('test_price_list.csv', @logger)

    # Mock the price list reading to avoid file dependency
    cost_calculator.instance_variable_set(:@price_list, [])

    # Test with nil car class
    result = cost_calculator.calculate_cost(['Диагностика'], nil)
    assert_nil result, "Should return nil for nil car class"
  end

  def test_fuzzy_service_match_with_nil_inputs
    cost_calculator = CostCalculator.new('test_price_list.csv', @logger)

    # Test with nil inputs - should not raise error
    result = cost_calculator.send(:fuzzy_service_match?, nil, 'Диагностика')
    assert_equal false, result, "Should return false for nil service name"

    result = cost_calculator.send(:fuzzy_service_match?, 'Диагностика', nil)
    assert_equal false, result, "Should return false for nil search name"

    result = cost_calculator.send(:fuzzy_service_match?, nil, nil)
    assert_equal false, result, "Should return false for both nil inputs"
  end

  # Test complete flow with edge cases
  def test_complete_admin_notification_with_all_nil_data
    request_detector = RequestDetector.new(@config, @logger)

    # Test the complete notification formatting with all nil/empty data
    request_info = {
      confidence: 1.0,
      original_text: 'Test message',
      car_info: nil,
      required_services: nil,
      cost_calculation: nil,
      dialog_context: nil,
      matched_patterns: nil
    }

    # This should not raise any errors
    notification = request_detector.send(:format_admin_notification, request_info, 123, 'testuser', 'Test')

    # Should only contain basic info, no empty sections
    assert_includes notification, "🔔 **НОВАЯ ЗАЯВКА**"
    assert_includes notification, "Test message"
    refute_includes notification, "🚗 **Информация об автомобиле:**"
    refute_includes notification, "🔧 **Необходимые работы:**"
    refute_includes notification, "💰 **Расчет стоимости:**"
    refute_includes notification, "💬 **Контекст диалога:**"
    refute_includes notification, "🔍 **Распознанные паттерны:**"
  end

  def test_complete_admin_notification_with_partial_data
    request_detector = RequestDetector.new(@config, @logger)

    # Test with mixed nil/valid data
    request_info = {
      confidence: 1.0,
      original_text: 'Toyota Camry, нужна диагностика',
      car_info: { make_model: 'Toyota Camry', class: 2 },  # Valid data
      required_services: nil,  # Nil data
      cost_calculation: { total: 'от 1000 руб.' },  # Valid data
      dialog_context: '',  # Empty string
      matched_patterns: []  # Empty array
    }

    # This should not raise any errors
    notification = request_detector.send(:format_admin_notification, request_info, 123, 'testuser', 'Test')

    # Should contain sections with data, but not empty sections
    assert_includes notification, "🔔 **НОВАЯ ЗАЯВКА**"
    assert_includes notification, "🚗 **Информация об автомобиле:**"
    assert_includes notification, "Toyota Camry"
    assert_includes notification, "💰 **Расчет стоимости:**"
    refute_includes notification, "🔧 **Необходимые работы:**"
    refute_includes notification, "💬 **Контекст диалога:**"
    refute_includes notification, "🔍 **Распознанные паттерны:**"
  end

  def teardown
    # Nothing to teardown - mocks are handled automatically by Minitest
  end
end