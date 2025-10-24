# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Telegram bot for a car service that uses Claude AI for conversation handling. The bot can operate in both polling and webhook modes and includes rate limiting, conversation management, and service pricing functionality.

## Common Development Commands

### Running the Application
```bash
# Start the bot (default mode: polling)
./bot.rb

# Install dependencies
bundle install

# Run tests
rake test
```

### Environment Setup
- Copy `.env.example` to `.env` and configure required variables
- Required: `TELEGRAM_BOT_TOKEN`
- Optional: `BOT_MODE` (polling/webhook), webhook settings

## Architecture Overview

The application follows a modular architecture with clear separation of concerns:

### Core Components
- **BotLauncher** (`lib/bot_launcher.rb`): Entry point that selects polling or webhook mode
- **TelegramBotHandler** (`lib/telegram_bot_handler.rb`): Main message processing logic
- **ConversationManager** (`lib/conversation_manager.rb`): Thread-safe conversation history storage
- **RateLimiter** (`lib/rate_limiter.rb`): In-memory rate limiting per user
- **PollingStarter** / **WebhookStarter**: Mode-specific bot starters

### Enriched Request System
- **DialogAnalyzer** (`lib/dialog_analyzer.rb`): Extracts car information and services from conversation history using regex patterns
- **CostCalculator** (`lib/cost_calculator.rb`): Calculates service costs based on car class and price list data
- **RequestDetector** (`lib/request_detector.rb`): Enhanced RubyLLM Tool that sends enriched requests to admin chat with car info, services, and cost calculations
- **LLMClient** (`lib/llm_client.rb`): Integrates DialogAnalyzer and CostCalculator for automatic request enrichment

### Configuration
- **AppConfig** (`config/app_config.rb`): Uses `anyway_config` gem for environment-based configuration with singleton pattern
- **Global Configuration Access**: All components access configuration directly through `AppConfig.setting_name` (no dependency injection)
- Validates required parameters and file existence (system prompt, welcome message, price list)
- Supports both polling and webhook modes with appropriate validation

### Logging
- **Application.logger**: Global logger singleton accessed through `Application.logger` throughout the application
- **Global Logger Access**: All components use `Application.logger.info/warn/error/debug` (no logger dependency injection)
- Logger configuration handled in Application with configurable log levels and output streams

### Data Sources
- **Service Pricing**: `data/price.csv` contains the complete price list for car services
- **System Prompt**: `data/system-prompt.md` defines Claude's behavior and context
- **Welcome Message**: `data/welcome-message.md` contains the welcome message for /start command with Markdown formatting
- **Implementation Plans**: Stored in `.protocols/` directory
- Спецификации (спеки) сохраняются в ./specs

## File Storage Rules

- **Implementation Plans**: ВСЕГДА сохраняются в `.protocols/` директорию
- **Specifications**: Сохраняются в `./specs/` директорию
- **Implementation Reports**: Сохраняются в корень проекта или `docs/`
- При создании плана имплементации ВСЕГДА используйте `.protocols/` - это обязательное правило

## Key Patterns

1. **Dependency Injection**: Components receive dependencies through constructors (except configuration and logger)
2. **Global Configuration Management**: All components access configuration directly through `AppConfig.setting_name` singleton pattern
3. **Global Logger Access**: All components use `Application.logger.method_name` for consistent logging throughout the application
4. **Mode Selection**: BotLauncher abstracts polling vs webhook implementation details
5. **Thread Safety**: ConversationManager uses Mutex for safe concurrent access
6. **Rate Limiting**: Per-user in-memory counters with automatic cleanup
7. **Welcome Message Management**: External file-based welcome messages with Markdown support and fallback handling
8. **Error Resilience**: Graceful fallbacks for file reading errors and API failures using anthropic gem's built-in error handling

## Testing

Tests are located in `test/` directory and use Minitest framework. Run with `rake test` or `make test`.

## Important Notes

- Прежде чем менять AppConfig или планировать его изменить изучаем gem
  anyway_config
- **Global Configuration Pattern**: All components access configuration directly through `AppConfig.setting_name` singleton pattern - no config dependency injection
- **Global Logger Pattern**: All components use `Application.logger.method_name` throughout the application - no logger dependency injection
- Do not read or use `.env*` files (per user instructions)
- Use MCP context7 for studying Ruby gems
- Service prices and implementation plans are referenced in CLAUDE.md for quick access
- ВСЕГДА сохраняйте планы имплементации в `.protocols/` - это строгое правило
- Спецификации сохраняйте в `./specs/`
- The bot supports Russian language interface (car service context)
- НЕ используются File.write и File.delete и прочие небезопасные методы в тестах
- НЕ изменеются ENV-ы в тестах
- Не удаляем спецификации даже если по ним уже выполнены планы имплементации
  (сами планы можно удалять)
- Логирование в тестах не мокается и НЕ проверяется
- По тому как использовать gem ruby_llm заглядывай в ./docs/gems/rubyllm.com