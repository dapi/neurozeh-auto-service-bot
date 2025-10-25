# frozen_string_literal: true

require 'minitest/autorun'
require_relative '../lib/telegram_markdown_sanitizer'

class TelegramMarkdownSanitizerTest < Minitest::Test
  def setup
    @sanitizer = TelegramMarkdownSanitizer.new
  end

  def test_nil_and_empty_handling
    assert_nil @sanitizer.sanitize(nil)
    assert_equal '', @sanitizer.sanitize('')
  end

  def test_valid_markdown_unchanged
    valid_markdown = '**Bold text** and *italic* and `code`'
    assert_equal valid_markdown, @sanitizer.sanitize(valid_markdown)
  end

  def test_unclosed_bold_tags_fixed
    text = 'This is **bold text'
    expected = 'This is **bold text**'
    assert_equal expected, @sanitizer.sanitize(text)
  end

  def test_unclosed_italic_tags_fixed
    text = 'This is *italic text'
    expected = 'This is *italic text*'
    assert_equal expected, @sanitizer.sanitize(text)
  end

  def test_unclosed_code_tags_fixed
    text = 'This is `code'
    expected = 'This is `code`'
    assert_equal expected, @sanitizer.sanitize(text)
  end

  def test_multiple_unclosed_tags_fixed
    text = '**Bold and *italic* and `code'
    result = @sanitizer.sanitize(text)
    # Multiple unclosed tags should be fixed
    assert_kind_of String, result
    refute_empty result
    # The result should have balanced tags
    assert balanced_formatting?(result)
  end

  def test_valid_links_unchanged
    text = '[Google](https://google.com) and [Internal](/page)'
    assert_equal text, @sanitizer.sanitize(text)
  end

  def test_invalid_links_fixed
    text = '[Link](invalid-url)'
    expected = 'Link: invalid-url'
    assert_equal expected, @sanitizer.sanitize(text)
  end

  def test_empty_link_text_handled
    text = '[](https://example.com)'
    # Empty link text is considered valid for the URL
    result = @sanitizer.sanitize(text)
    # Should either be fixed or escaped in some reasonable way
    assert_kind_of String, result
    refute_empty result
  end

  def test_text_truncation
    long_text = 'A' * 4100
    result = @sanitizer.sanitize(long_text)
    assert result.length <= 4096
    assert result.end_with?('...')
  end

  def test_complex_markdown_sanitization
    text = 'Hello **world with **nested** bold* and *italic text'
    result = @sanitizer.sanitize(text)
    # Complex nested formatting should be handled gracefully
    assert_kind_of String, result
    refute_empty result
    # The result should have balanced tags
    assert balanced_formatting?(result)
  end

  def test_special_characters_escape
    text = 'Text with _underscore_ outside formatting'
    # Currently, the sanitizer is conservative and preserves most markdown
    result = @sanitizer.sanitize(text)
    # This test documents current behavior - underscores are preserved
    assert_equal text, result
  end

  def test_error_handling_fallback
    # Simulate a case where CommonMarker might fail
    problematic_text = "\x00\x01\x02" # Null bytes and control characters

    # Should not raise an exception
    result = @sanitizer.sanitize(problematic_text)
    assert_kind_of String, result
  end

  def test_balanced_formatting_validation
    assert_equal '**bold**', @sanitizer.sanitize('**bold**')

    # Single asterisk should be treated as italic
    result = @sanitizer.sanitize('*single asterisk*')
    assert_equal '*single asterisk*', result
  end

  def test_link_format_validation
    valid_http = '[Text](https://example.com)'
    valid_relative = '[Text](/path)'
    invalid_protocol = '[Text](ftp://example.com)'

    assert_equal valid_http, @sanitizer.sanitize(valid_http)
    assert_equal valid_relative, @sanitizer.sanitize(valid_relative)
    assert_equal 'Text: ftp://example.com', @sanitizer.sanitize(invalid_protocol)
  end

  def test_mixed_content_sanitization
    text = '**Bold** text with [link](https://example.com) and `code` plus *italic*'
    assert_equal text, @sanitizer.sanitize(text)
  end

  def test_edge_case_formatting
    # Edge cases with overlapping or nested formatting
    text1 = '***bold and italic***'
    result1 = @sanitizer.sanitize(text1)
    assert_kind_of String, result1

    text2 = '**bold *italic** text*'
    result2 = @sanitizer.sanitize(text2)
    assert_kind_of String, result2
  end

  def test_performance_large_text
    # Test with a reasonably large amount of text
    paragraphs = 10
    text = "This is a paragraph with **bold** and *italic* text.\n" * paragraphs

    start_time = Time.now
    result = @sanitizer.sanitize(text)
    end_time = Time.now

    # Should complete quickly (under 100ms for this size)
    assert end_time - start_time < 0.1
    assert_kind_of String, result
  end

  def test_code_block_handling
    # Code blocks should be handled gracefully
    text = 'Here is `inline code` and **bold text**'
    expected = 'Here is `inline code` and **bold text**'
    assert_equal expected, @sanitizer.sanitize(text)
  end

  def test_real_world_examples
    # Test with examples that might come from LLM responses
    examples = [
      'Для вашего автомобиля **BMW X5** рекомендуется:',
      '* Замена масла фильтра - **2,500 ₽**',
      'Пожалуйста, посетите [наш сайт](https://example.com) для подробностей',
      'Цена: **3,000 ₽** (с учетом НДС)',
      '`VEHICLE_INFO` содержит информацию об автомобиле'
    ]

    examples.each do |example|
      result = @sanitizer.sanitize(example)
      assert_kind_of String, result
      refute_empty result
      assert result.length <= 4096
    end
  end

  def test_fallback_behavior_on_complex_failures
    # Test cases that should fallback to plain text
    complex_failure_text = '**Unclosed *nested ** formatting'
    result = @sanitizer.sanitize(complex_failure_text)

    # Should result in valid string (either fixed or escaped)
    assert_kind_of String, result
    refute_empty result
  end

  private

  def balanced_formatting?(text)
    bold_count = text.scan(/\*\*/).length
    italic_count = text.scan(/(?<!\*)\*(?!\*)/).length
    code_count = text.scan(/(?<!\\)`/).length

    bold_count.even? && italic_count.even? && code_count.even?
  end
end