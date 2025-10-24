# frozen_string_literal: true

require_relative 'test_helper'
require_relative '../lib/request_detector'
require 'ostruct'

class TestRequestDetector < Minitest::Test
  def setup
    @config = Minitest::Mock.new
    @config.expect :admin_chat_id, 123456789
    @config.expect :telegram_bot_token, 'test_token'

    # Use NullLogger for tests to avoid actual logging
    @logger = NullLogger.new
    @detector = RequestDetector.new(@config, @logger)
  end

  def test_detect_booking_request
    # Mock Telegram bot API
    telegram_bot_mock = Minitest::Mock.new
    api_mock = Minitest::Mock.new
    telegram_bot_mock.expect :api, api_mock

    # Verify that send_message is called with correct parameters
    api_mock.expect :send_message, nil do |args|
      args[:chat_id] == 123456789 &&
      args[:parse_mode] == 'Markdown' &&
      args[:text].is_a?(String) &&
      args[:text].include?('НОВАЯ ЗАЯВКА')
    end

    Telegram::Bot::Client.stub(:new, telegram_bot_mock) do
      result = @detector.execute(
        message_text: 'Хочу записаться на диагностику подвески',
        user_id: 123,
        username: 'testuser',
        first_name: 'Test'
      )

      assert result[:success]
      assert_includes result[:message], 'Заявка отправлена'
    end

    @config.verify
  end

  def test_detect_pricing_request_via_execute
    # execute method always succeeds when called by LLM
    telegram_bot_mock = Minitest::Mock.new
    api_mock = Minitest::Mock.new
    telegram_bot_mock.expect :api, api_mock

    api_mock.expect :send_message, nil do |args|
      args[:chat_id] == 123456789 &&
      args[:parse_mode] == 'Markdown' &&
      args[:text].is_a?(String)
    end

    Telegram::Bot::Client.stub(:new, telegram_bot_mock) do
      result = @detector.execute(
        message_text: 'Сколько стоит замена масла для Renault Logan?',
        user_id: 456,
        username: nil,
        first_name: 'Иван'
      )

      assert result[:success]
    end
  end

  def test_detect_service_request_via_execute
    # execute method always succeeds when called by LLM
    telegram_bot_mock = Minitest::Mock.new
    api_mock = Minitest::Mock.new
    telegram_bot_mock.expect :api, api_mock

    api_mock.expect :send_message, nil do |args|
      args[:chat_id] == 123456789 &&
      args[:parse_mode] == 'Markdown' &&
      args[:text].is_a?(String)
    end

    Telegram::Bot::Client.stub(:new, telegram_bot_mock) do
      result = @detector.execute(
        message_text: 'Нужно сделать диагностику двигателя',
        user_id: 789
      )

      assert result[:success]
    end
  end

  def test_detect_consultation_request_via_execute
    # execute method always succeeds when called by LLM
    telegram_bot_mock = Minitest::Mock.new
    api_mock = Minitest::Mock.new
    telegram_bot_mock.expect :api, api_mock

    api_mock.expect :send_message, nil do |args|
      args[:chat_id] == 123456789 &&
      args[:parse_mode] == 'Markdown' &&
      args[:text].is_a?(String)
    end

    Telegram::Bot::Client.stub(:new, telegram_bot_mock) do
      result = @detector.execute(
        message_text: 'Помогите выбрать лучшие тормозные колодки для Kia Rio',
        user_id: 111,
        username: 'carowner',
        first_name: 'Алексей'
      )

      assert result[:success]
    end
  end

  
  def test_no_admin_chat_configured
    config_no_admin = Minitest::Mock.new
    config_no_admin.expect :admin_chat_id, nil

    logger_no_admin = NullLogger.new
    detector_no_admin = RequestDetector.new(config_no_admin, logger_no_admin)

    result = detector_no_admin.execute(
      message_text: 'Хочу на сервис',
      user_id: 444
    )

    refute result[:success]
    # Now it will try to send but fail due to nil admin_chat_id
    assert_includes result[:error], 'Telegram API error'

    config_no_admin.verify
  end

  def test_telegram_api_error
    # Mock config for this test
    config_error = Minitest::Mock.new
    config_error.expect :admin_chat_id, 123456789
    config_error.expect :telegram_bot_token, 'test_token'

    detector_error = RequestDetector.new(config_error)

    # Mock Telegram API that raises an error
    telegram_bot_mock = Minitest::Mock.new
    api_mock = Minitest::Mock.new
    telegram_bot_mock.expect :api, api_mock

    api_mock.expect :send_message, nil do
      # Create a proper ResponseError with response object
      response = OpenStruct.new(body: '{"ok":false,"error_code":400,"description":"Bad request"}')
      raise Telegram::Bot::Exceptions::ResponseError.new(response)
    end

    Telegram::Bot::Client.stub(:new, telegram_bot_mock) do
      result = detector_error.execute(
        message_text: 'Записаться на ТО',
        user_id: 555
      )

      refute result[:success]
      # The error should include "Telegram API error" message
      assert_match(/Telegram API error/i, result[:error])
    end

    config_error.verify
  end

  def test_request_with_context_via_execute
    # execute method always succeeds when called by LLM regardless of context
    context = "user: У меня проблема с тормозами\nassistant: Здравствуйте! Я помогу вам с проблемой тормозов."

    telegram_bot_mock = Minitest::Mock.new
    api_mock = Minitest::Mock.new
    telegram_bot_mock.expect :api, api_mock

    api_mock.expect :send_message, nil do |args|
      args[:chat_id] == 123456789 &&
      args[:parse_mode] == 'Markdown' &&
      args[:text].is_a?(String)
    end

    Telegram::Bot::Client.stub(:new, telegram_bot_mock) do
      result = @detector.execute(
        message_text: 'Когда можете посмотреть?',
        user_id: 666,
        conversation_context: context
      )

      assert result[:success], "Expected request to be detected, got: #{result}"
    end
  end
end