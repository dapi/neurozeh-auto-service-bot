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
- **AppConfig** (`config/app_config.rb`): Uses `anyway_config` gem for environment-based configuration
- Validates required parameters and file existence (system prompt, welcome message, price list)
- Supports both polling and webhook modes with appropriate validation

### Data Sources
- **Service Pricing**: `data/price.csv` contains the complete price list for car services
- **System Prompt**: `data/system-prompt.md` defines Claude's behavior and context
- **Welcome Message**: `data/welcome-message.md` contains the welcome message for /start command with Markdown formatting
- **Implementation Plans**: Stored in `.protocols/` directory
- Спецификации (спеки) сохраняются в ./specs

## Key Patterns

1. **Dependency Injection**: Components receive dependencies through constructors
2. **Configuration Management**: Centralized through AppConfig with environment validation
3. **Mode Selection**: BotLauncher abstracts polling vs webhook implementation details
4. **Thread Safety**: ConversationManager uses Mutex for safe concurrent access
5. **Rate Limiting**: Per-user in-memory counters with automatic cleanup
6. **Welcome Message Management**: External file-based welcome messages with Markdown support and fallback handling
7. **Error Resilience**: Graceful fallbacks for file reading errors and API failures using anthropic gem's built-in error handling

## Testing

Tests are located in `test/` directory and use Minitest framework. Run with `rake test` or `make test`.

## Important Notes

- Прежде чем менять AppConfig или планировать его изменить изучаем gem
  anyway_config
- Do not read or use `.env*` files (per user instructions)
- Use MCP context7 for studying Ruby gems
- Service prices and implementation plans are referenced in CLAUDE.md for quick access
- The bot supports Russian language interface (car service context)
- НЕ используются File.write и File.delete и прочие небезопасные методы в тестах
- НЕ изменеются ENV-ы в тестах
- Не удаляем спецификации даже если по ним уже выполнены планы имплементации
  (сами планы можно удалять)
- Логирование в тестах не мокается и НЕ проверяется