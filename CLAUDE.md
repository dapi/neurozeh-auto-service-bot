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
- **ClaudeClient** (`lib/claude_client.rb`): Claude API communication using official anthropic gem
- **ConversationManager** (`lib/conversation_manager.rb`): Thread-safe conversation history storage
- **RateLimiter** (`lib/rate_limiter.rb`): In-memory rate limiting per user
- **PollingStarter** / **WebhookStarter**: Mode-specific bot starters

### Configuration
- **AppConfig** (`config/app_config.rb`): Uses `anyway_config` gem for environment-based configuration
- Validates required parameters and file existence (system prompt, welcome message, price list)
- Supports both polling and webhook modes with appropriate validation
- **Environment Variables**: `ANTHROPIC_AUTH_TOKEN`, `TELEGRAM_BOT_TOKEN`, `SYSTEM_PROMPT_PATH`, `WELCOME_MESSAGE_PATH`

### Data Sources
- **Service Pricing**: `data/кузник.csv` contains the complete price list for car services
- **System Prompt**: `config/system-prompt.md` defines Claude's behavior and context
- **Welcome Message**: `config/welcome-message.md` contains the welcome message for /start command with Markdown formatting
- **Implementation Plans**: Stored in `.protocols/` directory

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

- Do not read or use `.env*` files (per user instructions)
- Use MCP context7 for studying Ruby gems
- Service prices and implementation plans are referenced in CLAUDE.md for quick access
- The bot supports Russian language interface (car service context)
- НЕ используются File.write и File.delete и прочие Не безопасные методы в тестах
- НЕ изменеются ENV-ы в тестах

## SSL Certificate Issues

### Problem
When using custom API endpoints (like `api.z.ai`), you may encounter SSL certificate verification errors:
```
OpenSSL::SSL::SSLError - SSL_connect returned=1 errno=0 peeraddr=... state=error: certificate verify failed (unable to get certificate CRL)
```

### Solutions

#### 1. Automatic SSL Patch (Recommended)
The application includes automatic SSL handling for problematic hosts:
- SSL verification is automatically disabled for `api.z.ai`
- You can enable strict SSL verification with `ALLOW_SSL_VERIFY=true`
- You can manually disable SSL verification with `DISABLE_SSL_VERIFY=true`

#### 2. Manual SSL Patch
If automatic handling doesn't work, load the SSL patch before the bot:
```bash
ruby -r ./patch_ssl.rb bot.rb
```

#### 3. Environment Variables
Use these environment variables to control SSL behavior:
- `ALLOW_SSL_VERIFY=true` - Force strict SSL verification
- `DISABLE_SSL_VERIFY=true` - Force disable SSL verification
- `SSL_CERT_FILE=/dev/null` - Disable certificate verification
- `CURL_CA_BUNDLE=/dev/null` - Disable CA bundle verification

### Common API Endpoint Issues

If you see 410 Gone errors, the API endpoint may have changed. Current known issues:
- `https://api.z.ai/api/anthropic/v1/messages` returns 410 Gone
- Try contacting your API provider for the correct endpoint URL

### Testing SSL Connection
Use the provided test script to diagnose SSL issues:
```bash
ruby test_claude_connection.rb
```
