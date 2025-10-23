# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a Telegram bot for a car service (Kuznik) that uses Claude AI for conversation handling. The bot can operate in both polling and webhook modes and includes rate limiting, conversation management, and service pricing functionality.

## Common Development Commands

### Running the Application
```bash
# Start the bot (default mode: polling)
ruby bot.rb

# Install dependencies
bundle install

# Run tests
rake test
# or
make test
```

### Environment Setup
- Copy `.env.example` to `.env` and configure required variables
- Required: `ANTHROPIC_AUTH_TOKEN`, `TELEGRAM_BOT_TOKEN`
- Optional: `BOT_MODE` (polling/webhook), webhook settings

## Architecture Overview

The application follows a modular architecture with clear separation of concerns:

### Core Components
- **BotLauncher** (`lib/bot_launcher.rb`): Entry point that selects polling or webhook mode
- **TelegramBotHandler** (`lib/telegram_bot_handler.rb`): Main message processing logic
- **ClaudeClient** (`lib/claude_client.rb`): HTTP client for Claude API communication
- **ConversationManager** (`lib/conversation_manager.rb`): Thread-safe conversation history storage
- **RateLimiter** (`lib/rate_limiter.rb`): In-memory rate limiting per user
- **PollingStarter** / **WebhookStarter**: Mode-specific bot starters

### Configuration
- **AppConfig** (`config/app_config.rb`): Uses `anyway_config` gem for environment-based configuration
- Validates required parameters and system prompt file existence
- Supports both polling and webhook modes with appropriate validation

### Data Sources
- **Service Pricing**: `data/кузник.csv` contains the complete price list for car services
- **System Prompt**: `system-prompt.md` defines Claude's behavior and context
- **Implementation Plans**: Stored in `.protocols/` directory

## Key Patterns

1. **Dependency Injection**: Components receive dependencies through constructors
2. **Configuration Management**: Centralized through AppConfig with environment validation
3. **Mode Selection**: BotLauncher abstracts polling vs webhook implementation details
4. **Thread Safety**: ConversationManager uses Mutex for safe concurrent access
5. **Rate Limiting**: Per-user in-memory counters with automatic cleanup

## Testing

Tests are located in `test/` directory and use Minitest framework. Run with `rake test` or `make test`.

## Important Notes

- Do not read or use `.env*` files (per user instructions)
- Use MCP context7 for studying Ruby gems
- Service prices and implementation plans are referenced in CLAUDE.md for quick access
- The bot supports Russian language interface (car service context)