# frozen_string_literal: true

require 'commonmarker'

class TelegramMarkdownSanitizer
  TELEGRAM_MAX_LENGTH = 4096
  TELEGRAM_MARKDOWN_SYMBOLS = %w[* _ ~ ` [ ] ( )].freeze

  def initialize(options = {})
    @commonmarker_options = options[:commonmarker] || default_commonmarker_options
    @logger = options[:logger]
  end

  def sanitize(text)
    return text if text.nil? || text.empty?

    begin
      # Ensure text length limit
      text = truncate_text(text)

      # First try to fix basic formatting issues
      sanitized = fix_unclosed_tags(text)
      sanitized = fix_invalid_links(sanitized)

      # Only if the original text had obvious formatting issues,
      # otherwise return it as-is to preserve valid markdown
      if text == sanitized && valid_telegram_markdown?(text)
        return text
      end

      # If we made changes, validate the result
      if valid_telegram_markdown?(sanitized)
        @logger.debug("Markdown sanitized successfully") if @logger
        return sanitized
      else
        # If still invalid, try to be more conservative
        # or fall back to plain text if necessary
        @logger.warn("Markdown sanitization failed, using plain text") if @logger
        return escape_all_markdown(text)
      end

    rescue StandardError => e
      @logger.error("Error during markdown sanitization: #{e.message}") if @logger
      # Fallback to plain text on any error
      escape_all_markdown(text)
    end
  end

  private

  def default_commonmarker_options
    {
      parse: {
        smart: false,
        hardbreaks: false,
        normalized: false,
        validate_utf8: true
      },
      render: {
        hardbreaks: false,
        width: TELEGRAM_MAX_LENGTH
      }
    }
  end

  def valid_telegram_markdown?(text)
    # Check basic balance of formatting characters
    return false unless balanced_formatting_chars?(text)

    # Check links format
    return false unless valid_links?(text)

    # Check maximum length
    return false if text.length > TELEGRAM_MAX_LENGTH

    true
  end

  def balanced_formatting_chars?(text)
    # Count bold, italic, code, and other formatting characters
    bold_count = text.scan(/\*\*/).length
    italic_count = text.scan(/(?<!\*)\*(?!\*)/).length
    code_count = text.scan(/`/).length

    # All formatting should be balanced (even count)
    bold_count.even? && italic_count.even? && code_count.even?
  end

  def valid_links?(text)
    # Check for markdown links [text](url)
    links = text.scan(/\[([^\]]*)\]\(([^)]*)\)/)
    links.all? do |link_text, url|
      !link_text.empty? && valid_url?(url)
    end
  end

  def valid_url?(url)
    # Basic URL validation for Telegram
    url.match?(/\Ahttps?:\/\/.+/) || url.match?(/\A\/.+/)
  end

  def fix_unclosed_tags(text)
    result = text.dup

    # Fix unclosed bold tags (count ** as pairs)
    bold_count = result.scan(/\*\*/).length
    if bold_count.odd?
      result += '**'
    end

    # Fix unclosed code tags
    code_count = result.scan(/(?<!\\)`/).length
    if code_count.odd?
      result += '`'
    end

    # Handle italic tags - be more careful to avoid interfering with bold
    # Remove bold pairs temporarily to handle italic properly
    text_without_bold = result.gsub(/\*\*/, '')
    italic_count = text_without_bold.scan(/(?<!\\)\*(?!\*)/).length
    if italic_count.odd?
      # Add italic tag at the end
      result += '*'
    end

    result
  end

  def fix_invalid_links(text)
    # Fix links without proper format
    text.gsub(/\[([^\]]*)\]\(([^)]*)\)/) do |match|
      link_text = Regexp.last_match(1)
      url = Regexp.last_match(2).strip

      if valid_url?(url)
        match # Return original match if valid
      else
        # Fallback to plain text format only for obviously invalid URLs
        "#{link_text}: #{url}"
      end
    end
  end

  def escape_special_chars(text)
    # For Telegram, we generally don't need to escape special characters
    # unless they're causing formatting issues
    # We'll be conservative and only escape when necessary
    text
  end

  def escape_all_markdown(text)
    # Escape all markdown characters for plain text fallback
    text.gsub(/[*_~`\[\]()]/) { |c| "\\#{c}" }
  end

  def truncate_text(text)
    return text if text.length <= TELEGRAM_MAX_LENGTH

    # Truncate with ellipsis while trying to preserve formatting
    truncated = text[0, TELEGRAM_MAX_LENGTH - 3]

    # Close any unclosed formatting tags
    sanitized = fix_unclosed_tags(truncated)

    if sanitized.length > TELEGRAM_MAX_LENGTH
      # If still too long after fixing tags, truncate more aggressively
      sanitized[0, TELEGRAM_MAX_LENGTH - 3] + '...'
    else
      sanitized + '...'
    end
  end
end