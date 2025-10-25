# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../../lib/telegram_markdown_sanitizer'
require_relative '../../lib/llm_client'

class MarkdownTelegramIntegrationTest < Minitest::Test
  def setup
    @sanitizer = TelegramMarkdownSanitizer.new
  end

  def test_full_markdown_sanitization_flow
    # Test the complete flow from problematic markdown to safe markdown
    test_cases = [
      {
        name: 'valid markdown',
        input: 'Для вашего автомобиля **BMW X5** рекомендуется:',
        expected: 'Для вашего автомобиля **BMW X5** рекомендуется:'
      },
      {
        name: 'unclosed bold',
        input: 'Это **жирный текст без закрытия',
        expected: 'Это **жирный текст без закрытия**'
      },
      {
        name: 'mixed formatting',
        input: '**Жирный** текст с *курсивом* и `кодом`',
        expected: '**Жирный** текст с *курсивом* и `кодом`'
      },
      {
        name: 'valid links',
        input: 'Посетите [Google](https://google.com) для информации',
        expected: 'Посетите [Google](https://google.com) для информации'
      },
      {
        name: 'invalid links',
        input: 'Неверная [ссылка](ftp://example.com)',
        expected: 'Неверная ссылка: ftp://example.com'
      },
      {
        name: 'complex formatting with unclosed tags',
        input: '**Незакрытый *курсив и `код',
        expected: '**Незакрытый *курсив и `код**`*'
      }
    ]

    test_cases.each do |test_case|
      result = @sanitizer.sanitize(test_case[:input])
      assert_kind_of String, result, "#{test_case[:name]}: result should be a string"
      refute_empty result, "#{test_case[:name]}: result should not be empty"

      # If we have expected result, check it
      if test_case[:expected]
        assert_equal test_case[:expected], result, "#{test_case[:name]}: expected output"
      end

      # Result should have balanced formatting
      assert balanced_formatting?(result), "#{test_case[:name]}: result should have balanced formatting"
    end
  end

  def test_length_limits_handling
    # Test that long text is properly truncated
    long_text = 'A' * 5000
    result = @sanitizer.sanitize(long_text)

    assert result.length <= 4096, "Result should not exceed Telegram limit"
    assert result.end_with?('...'), "Result should end with ellipsis when truncated"
  end

  def test_real_world_llm_responses
    # Test with examples that might come from LLM
    llm_examples = [
      'Для вашего **Toyota Camry** 2022 года рекомендуем:\n* Замена масла - **3,500 ₽**\n* Замена фильтров - **1,200 ₽**\n\nИтого: **4,700 ₽**',
      'Цена на ремонт **генератора** для Honda Civic составляет **12,000 ₽**\n\nСрок выполнения: 1-2 дня',
      '`ENGINE_DIAGNOSTICS` показала ошибки:\n- P0420: Катализатор\n- P0300: Пропуски зажигания\n\nРекомендуем обратиться в сервис',
      'Пожалуйста, посетите [наш сайт](https://example.com) для записи на ТО'
    ]

    llm_examples.each_with_index do |example, i|
      result = @sanitizer.sanitize(example)
      assert_kind_of String, result, "Example #{i}: should be a string"
      refute_empty result, "Example #{i}: should not be empty"
      assert result.length <= 4096, "Example #{i}: should not exceed length limit"
      assert balanced_formatting?(result), "Example #{i}: should have balanced formatting"
    end
  end

  def test_error_recovery_scenarios
    # Test that the sanitizer gracefully handles problematic input
    error_cases = [
      '',  # empty string
      nil,  # nil
      'Пустые теги: **** или `````',  # empty formatting
      'Вложенные **теги **внутри** других** тегов',  # nested formatting
      "Текст с\nпереносами строк и **форматированием**",  # multiline with formatting
      'Смешанная `**разметка**` разного типа'  # mixed formatting
    ]

    error_cases.each_with_index do |test_input, i|
      # Should not raise exceptions
      assert_nothing_raised do
        result = @sanitizer.sanitize(test_input)
        # Handle nil case explicitly
        if test_input.nil?
          assert_nil result, "Error case #{i}: nil input should return nil"
        else
          assert_kind_of String, result, "Error case #{i}: should return string"
          # If input is not empty, result should not be empty
          if !test_input.empty?
            refute_empty result, "Error case #{i}: should not return empty for non-empty input"
          end
        end
      end
    end
  end

  def test_performance_with_large_content
    # Test performance with realistically sized content
    large_content = "## Диагностика автомобиля\n\n" +
                   "**Автомобиль**: BMW X5 2021\n" +
                   "**Пробег**: 45,000 км\n\n" +
                   "### Обнаруженные проблемы:\n\n" +
                   "* Двигатель: **требует внимания**\n" +
                   "* Тормоза: **в норме**\n" +
                   "* Подвеска: **проверить амортизаторы**\n\n" +
                   "### Рекомендуемые работы:\n\n" +
                   "1. Замена масла в двигателе - **2,500 ₽**\n" +
                   "2. Замена воздушного фильтра - **800 ₽**\n" +
                   "3. Диагностика подвески - **1,200 ₽**\n\n" +
                   "**Общая стоимость**: **4,500 ₽**\n\n" +
                   "Срок выполнения: 2-3 часа\n\n" +
                   "Для записи: [Забронировать время](https://example.com/booking)\n\n" +
                   "`NOTE: Цены актуальны на текущий месяц`"

    start_time = Time.now
    result = @sanitizer.sanitize(large_content)
    end_time = Time.now

    processing_time = end_time - start_time

    assert_kind_of String, result
    refute_empty result
    assert processing_time < 0.1, "Processing should complete quickly (< 100ms)"
    assert balanced_formatting?(result)
  end

  def test_telegram_specific_constraints
    # Test Telegram-specific constraints and edge cases
    telegram_cases = [
      {
        name: 'markdown with underscores',
        input: 'Используйте _форматирование_ для выделения текста',
        # Should preserve underscores (Telegram supports them)
        should_preserve: true
      },
      {
        name: 'markdown with special characters',
        input: 'Символы: * ~ [ ] ( )',
        # Should handle these gracefully
        should_preserve: true
      },
      {
        name: 'multiple consecutive formatting',
        input: '****сильное форматирование****',
        # Should handle multiple formatting characters
        should_preserve: true
      },
      {
        name: 'mixed latin and cyrillic',
        input: '**Bold текст** with *italic* and `кодовый`',
        should_preserve: true
      }
    ]

    telegram_cases.each do |test_case|
      result = @sanitizer.sanitize(test_case[:input])
      assert_kind_of String, result, "#{test_case[:name]}: should return string"
      assert balanced_formatting?(result), "#{test_case[:name]}: should be balanced"

      if test_case[:should_preserve]
        # For cases that should preserve formatting, check that formatting is still present
        formatting_chars = %w[* _ ~ `]
        has_formatting = formatting_chars.any? { |char| result.include?(char) }
        assert has_formatting, "#{test_case[:name]}: should preserve some formatting"
      end
    end
  end

  private

  def balanced_formatting?(text)
    return true if text.nil? || text.empty?

    bold_count = text.scan(/\*\*/).length
    italic_count = text.scan(/(?<!\*)\*(?!\*)/).length
    code_count = text.scan(/(?<!\\)`/).length

    bold_count.even? && italic_count.even? && code_count.even?
  end

  def assert_nothing_raised
    yield
  rescue => e
    flunk "Expected no exception, but got #{e.class}: #{e.message}"
  end
end