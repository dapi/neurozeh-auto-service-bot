# План имплементации: Поддержка режимов Polling и Webhook

## Этап 1: Подготовка (обновление конфигурации)

### 1.1 Обновить `config/app_config.rb`

**Что добавить**:
```ruby
attr_config(
  # ... существующие параметры ...

  # Bot mode configuration
  bot_mode: 'polling',                    # 'polling' или 'webhook'

  # Webhook configuration (для webhook режима)
  webhook_url: '',                         # https://example.com
  webhook_port: 3000,
  webhook_host: '0.0.0.0',
  webhook_path: '/telegram/webhook'
)
```

**Валидация в методе `validate!`**:
```ruby
if bot_mode == 'webhook' && webhook_url.blank?
  raise 'WEBHOOK_URL is required when BOT_MODE is webhook'
end

unless %w[polling webhook].include?(bot_mode)
  raise "BOT_MODE must be 'polling' or 'webhook', got: #{bot_mode}"
end
```

**Файл**: `config/app_config.rb` (строки после line 25)

---

## Этап 2: Создание стартеров

### 2.1 Создать `lib/polling_starter.rb`

**Файл**: `lib/polling_starter.rb`

```ruby
require 'logger'

class PollingStarter
  def initialize(config, logger, telegram_bot_handler)
    @config = config
    @logger = logger
    @telegram_bot_handler = telegram_bot_handler
  end

  def start
    @logger.info "Polling mode started"
    @logger.info "Listening for updates from Telegram..."
    @telegram_bot_handler.handle_polling
  end
end
```

**Ответственность**:
- Инкапсулирует логику запуска polling режима
- Делегирует обработку TelegramBotHandler

---

### 2.2 Создать `lib/webhook_starter.rb`

**Файл**: `lib/webhook_starter.rb`

```ruby
require 'logger'
require 'webrick'
require 'json'
require 'telegram/bot'

class WebhookStarter
  attr_reader :server

  def initialize(config, logger, telegram_bot_handler)
    @config = config
    @logger = logger
    @telegram_bot_handler = telegram_bot_handler
    @server = nil
  end

  def start
    @logger.info "Webhook mode started"
    @logger.info "Webhook URL: #{@config.webhook_url}"
    @logger.info "Server: #{@config.webhook_host}:#{@config.webhook_port}"

    setup_webhook
    start_http_server
  end

  private

  def setup_webhook
    @logger.info "Registering webhook with Telegram..."

    begin
      url = "#{@config.webhook_url}#{@config.webhook_path}"

      Telegram::Bot::Client.new(@config.telegram_bot_token).tap do |bot|
        response = bot.api.set_webhook(url: url)

        if response
          @logger.info "Webhook registered successfully: #{url}"
        else
          raise "Failed to register webhook"
        end
      end
    rescue => e
      @logger.error "Error registering webhook: #{e.message}"
      raise
    end
  end

  def start_http_server
    @logger.info "Starting HTTP server on #{@config.webhook_host}:#{@config.webhook_port}"

    server_config = {
      Port: @config.webhook_port,
      BindAddress: @config.webhook_host,
      AccessLog: [],  # Отключить access логи
      Logger: WEBrick::Log.new($stdout, WEBrick::Log::DEBUG)
    }

    @server = WEBrick::HTTPServer.new(server_config)

    # Регистрируем маршрут для вебхука
    @server.mount_proc(@config.webhook_path) do |req, res|
      handle_webhook_request(req, res)
    end

    # Graceful shutdown
    trap('INT') do
      @logger.info "Received SIGINT, shutting down webhook server..."
      @server.shutdown
    end

    @logger.info "Listening for webhook requests on #{@config.webhook_path}"
    @server.start
  end

  def handle_webhook_request(req, res)
    begin
      return handle_non_post(res) unless req.request_method == 'POST'

      body = req.body.read
      @logger.debug "Received webhook request: #{body[0..200]}"

      update_data = JSON.parse(body)

      # Конвертируем JSON в Telegram::Bot::Types::Update
      update = Telegram::Bot::Types::Update.new(update_data)

      # Обрабатываем сообщение если оно есть
      if update.message
        @telegram_bot_handler.handle_update(update)
      end

      res.status = 200
      res.content_type = 'application/json'
      res.body = { ok: true }.to_json

      @logger.debug "Webhook request processed successfully"
    rescue JSON::ParserError => e
      @logger.error "Invalid JSON in webhook request: #{e.message}"
      res.status = 400
      res.body = { ok: false, error: 'Invalid JSON' }.to_json
    rescue => e
      @logger.error "Error processing webhook request: #{e.message}"
      @logger.debug e.backtrace.join("\n")
      res.status = 500
      res.body = { ok: false, error: 'Internal server error' }.to_json
    end
  end

  def handle_non_post(res)
    res.status = 405
    res.body = { ok: false, error: 'Method not allowed' }.to_json
  end
end
```

**Ответственность**:
- Регистрирует вебхук в Telegram API
- Запускает HTTP сервер
- Обрабатывает входящие вебхук запросы
- Конвертирует JSON в объекты обновлений
- Логирует все операции и ошибки

---

### 2.3 Создать `lib/bot_launcher.rb`

**Файл**: `lib/bot_launcher.rb`

```ruby
require 'logger'

class BotLauncher
  def initialize(config, logger, telegram_bot_handler)
    @config = config
    @logger = logger
    @telegram_bot_handler = telegram_bot_handler
  end

  def start
    @logger.info "Bot starting in #{@config.bot_mode} mode..."

    case @config.bot_mode
    when 'polling'
      start_polling_mode
    when 'webhook'
      start_webhook_mode
    else
      raise "Unknown bot mode: #{@config.bot_mode}"
    end
  end

  private

  def start_polling_mode
    starter = PollingStarter.new(@config, @logger, @telegram_bot_handler)
    starter.start
  end

  def start_webhook_mode
    starter = WebhookStarter.new(@config, @logger, @telegram_bot_handler)
    starter.start
  end
end
```

**Ответственность**:
- Выбирает правильный стартер на основе конфигурации
- Инициирует запуск выбранного режима

---

## Этап 3: Обновление TelegramBotHandler

### 3.1 Изменить `lib/telegram_bot_handler.rb`

**Что изменить**:

1. **Переименовать метод `start` в `handle_polling`**:

```ruby
def handle_polling
  @logger.info "Starting Telegram bot with token: #{@config.telegram_bot_token[0..10]}..."

  Telegram::Bot::Client.run(@config.telegram_bot_token) do |bot|
    bot.listen do |message|
      handle_message(bot, message) if message.is_a?(Telegram::Bot::Types::Message)
    end
  end
end
```

2. **Добавить новый метод `handle_update`** для вебхуков:

```ruby
def handle_update(update)
  message = update.message
  return unless message

  # Создаем фейковый bot объект для совместимости
  # Или переделываем handle_message, чтобы он не требовал bot

  # Вариант 1: Использование Telegram::Bot::Client
  Telegram::Bot::Client.new(@config.telegram_bot_token) do |bot|
    handle_message(bot, message)
  end
end
```

**Или лучше** - рефакторить `handle_message` чтобы он не требовал bot параметр:

```ruby
def handle_message(message, bot_token = nil)
  user_id = message.from.id
  text = message.text
  chat_id = message.chat.id

  bot_token ||= @config.telegram_bot_token

  @logger.info "Received message from user #{user_id}: #{text[0..50]}..."

  # ... остальной код handle_message ...

  # В конце:
  Telegram::Bot::Client.new(bot_token) do |bot|
    send_telegram_response(bot, chat_id, response)
  end
end

private

def send_telegram_response(bot, chat_id, text)
  bot.api.send_message(
    chat_id: chat_id,
    text: text
  )
end
```

**Или еще лучше** - извлечь логику отправки сообщений:

```ruby
def handle_update(update)
  message = update.message
  return unless message

  user_id = message.from.id
  text = message.text
  chat_id = message.chat.id

  @logger.info "Received message from user #{user_id}: #{text[0..50]}..."

  # Handle /start command
  if text&.start_with?('/start')
    @logger.info "User #{user_id} issued /start command"
    @conversation_manager.clear_history(user_id)
    send_message(chat_id, "Привет! Я бот для записи на услуги автосервиса. Чем я могу вам помочь?")
    return
  end

  # Check rate limit
  unless @rate_limiter.allow?(user_id)
    @logger.warn "Rate limit exceeded for user #{user_id}"
    send_message(chat_id, "Вы отправляете слишком много сообщений. Пожалуйста, подождите немного.")
    return
  end

  # Process message with Claude
  begin
    @conversation_manager.add_message(user_id, 'user', text)
    history = @conversation_manager.get_history(user_id)
    response = @claude_client.send_message(history)
    @conversation_manager.add_message(user_id, 'assistant', response)
    send_message(chat_id, response)
    @logger.info "Successfully processed message for user #{user_id}"
  rescue StandardError => e
    @logger.error "Error processing message for user #{user_id}: #{e.message}"
    send_message(chat_id, "Произошла ошибка при обработке вашего сообщения. Пожалуйста, попробуйте позже.")
  end
end

private

def send_message(chat_id, text)
  Telegram::Bot::Client.new(@config.telegram_bot_token) do |bot|
    bot.api.send_message(chat_id: chat_id, text: text)
  end
end

def handle_polling
  @logger.info "Starting Telegram bot with token: #{@config.telegram_bot_token[0..10]}..."

  Telegram::Bot::Client.run(@config.telegram_bot_token) do |bot|
    bot.listen do |message|
      handle_update_from_polling(bot, message)
    end
  end
end

private

def handle_update_from_polling(bot, message)
  # Для polling режима нужно использовать bot объект для отправки
  # Значит нужна другая реализация
end
```

**РЕКОМЕНДУЕМЫЙ ПОДХОД** (простой и чистый):

Создать новый приватный метод `process_message` который содержит всю логику, а `handle_update` просто парсит update и вызывает `process_message`:

```ruby
class TelegramBotHandler
  # Public API

  def handle_polling
    @logger.info "Starting Telegram bot polling..."
    Telegram::Bot::Client.run(@config.telegram_bot_token) do |bot|
      bot.listen do |message|
        process_message(message, bot) if message.is_a?(Telegram::Bot::Types::Message)
      end
    end
  end

  def handle_update(update)
    message = update.message
    return unless message

    Telegram::Bot::Client.new(@config.telegram_bot_token) do |bot|
      process_message(message, bot)
    end
  end

  private

  def process_message(message, bot)
    # Вся существующая логика handle_message
  end

  alias_method :handle_message, :process_message  # Для обратной совместимости
end
```

---

## Этап 4: Обновление точки входа

### 4.1 Изменить `bot.rb`

**Что изменить**:

```ruby
# В конце файла, заменить:
telegram_bot_handler.start

# На:
launcher = BotLauncher.new(config, logger, telegram_bot_handler)
launcher.start
```

**Полный файл после изменений** (строки 44-61):

```ruby
# Initialize components
rate_limiter = RateLimiter.new(
  config.rate_limit_requests,
  config.rate_limit_period
)
logger.info "RateLimiter initialized"

conversation_manager = ConversationManager.new(config.max_history_size)
logger.info "ConversationManager initialized"

claude_client = ClaudeClient.new(config, logger)
logger.info "ClaudeClient initialized"

telegram_bot_handler = TelegramBotHandler.new(
  config,
  claude_client,
  rate_limiter,
  conversation_manager,
  logger
)
logger.info "TelegramBotHandler initialized"

# Launch bot with appropriate mode
launcher = BotLauncher.new(config, logger, telegram_bot_handler)
logger.info "BotLauncher initialized for mode: #{config.bot_mode}"

# Handle signals
trap('INT') do
  logger.info "Received SIGINT, shutting down..."
  exit(0)
end

# Start the bot
logger.info "Starting bot..."
launcher.start
```

**Требуемые require в bot.rb**:

```ruby
require_relative 'lib/bot_launcher'
require_relative 'lib/polling_starter'
require_relative 'lib/webhook_starter'
```

---

## Этап 5: Обновление конфигурации (файлы для пользователя)

### 5.1 Обновить `.env.example`

**Добавить**:

```bash
# Bot mode: 'polling' or 'webhook'
BOT_MODE=polling

# Webhook configuration (required if BOT_MODE=webhook)
WEBHOOK_URL=https://example.com
WEBHOOK_PORT=3000
WEBHOOK_HOST=0.0.0.0
WEBHOOK_PATH=/telegram/webhook
```

---

### 5.2 Обновить `README.md`

**Добавить раздел**:

```markdown
## Режимы запуска бота

### Режим 1: Polling (по умолчанию)
Бот активно опрашивает Telegram API на предмет новых сообщений.

**Плюсы**:
- Легко тестировать локально
- Работает за NAT и файерволами
- Не требует HTTPS сертификата

**Минусы**:
- Более медленный ответ на сообщения
- Больше нагрузки на CPU и API лимиты

**Запуск**:
```bash
export BOT_MODE=polling
ruby bot.rb
```

### Режим 2: Webhook
Telegram отправляет обновления на ваш сервер через HTTPS.

**Плюсы**:
- Быстрый ответ на сообщения (~25ms)
- Экономит API лимиты
- Подходит для production

**Минусы**:
- Требует HTTPS сертификат
- Требует публичный IP или доменное имя
- Сложнее тестировать локально

**Запуск**:
```bash
export BOT_MODE=webhook
export WEBHOOK_URL=https://your-domain.com
export WEBHOOK_PORT=3000
ruby bot.rb
```

**Генерация самоподписанного сертификата** (для тестирования):
```bash
openssl req -x509 -newkey rsa:4096 -nodes -out cert.pem -keyout key.pem -days 365
```
```

---

## Этап 6: Тестирование

### 6.1 Создать `test/test_bot_launcher.rb`

```ruby
require_relative '../test_helper'
require_relative '../lib/bot_launcher'
require_relative '../lib/polling_starter'
require_relative '../lib/webhook_starter'

class TestBotLauncher < Minitest::Test
  def setup
    @config = Minitest::Mock.new
    @logger = Minitest::Mock.new
    @telegram_bot_handler = Minitest::Mock.new
  end

  def test_polling_mode_creates_polling_starter
    @config.expect(:bot_mode, 'polling')

    launcher = BotLauncher.new(@config, @logger, @telegram_bot_handler)

    # Проверяем что PollingStarter создается
    PollingStarter.stub :new, Minitest::Mock.new.expect(:start, nil) do
      launcher.start
    end
  end

  def test_webhook_mode_creates_webhook_starter
    @config.expect(:bot_mode, 'webhook')

    launcher = BotLauncher.new(@config, @logger, @telegram_bot_handler)

    # Проверяем что WebhookStarter создается
    WebhookStarter.stub :new, Minitest::Mock.new.expect(:start, nil) do
      launcher.start
    end
  end

  def test_unknown_mode_raises_error
    @config.expect(:bot_mode, 'invalid')

    launcher = BotLauncher.new(@config, @logger, @telegram_bot_handler)

    assert_raises(RuntimeError) { launcher.start }
  end
end
```

### 6.2 Создать `test/test_polling_starter.rb`

```ruby
require_relative '../test_helper'
require_relative '../lib/polling_starter'

class TestPollingStarter < Minitest::Test
  def setup
    @config = Minitest::Mock.new
    @logger = Minitest::Mock.new
    @telegram_bot_handler = Minitest::Mock.new
  end

  def test_polling_starter_calls_handle_polling
    @logger.expect(:info, nil, ["Polling mode started"])
    @logger.expect(:info, nil, ["Listening for updates from Telegram..."])
    @telegram_bot_handler.expect(:handle_polling, nil)

    starter = PollingStarter.new(@config, @logger, @telegram_bot_handler)
    starter.start
  end
end
```

### 6.3 Создать `test/test_webhook_starter.rb`

```ruby
require_relative '../test_helper'
require_relative '../lib/webhook_starter'

class TestWebhookStarter < Minitest::Test
  def setup
    @config = Minitest::Mock.new
    @logger = Minitest::Mock.new
    @telegram_bot_handler = Minitest::Mock.new
  end

  def test_webhook_registration
    @config.expect(:bot_mode, 'webhook')
    @config.expect(:webhook_url, 'https://example.com')
    @config.expect(:webhook_path, '/telegram/webhook')
    @config.expect(:webhook_host, '0.0.0.0')
    @config.expect(:webhook_port, 3000)
    @config.expect(:telegram_bot_token, 'test_token')

    @logger.expect(:info, nil, ["Webhook mode started"])
    @logger.expect(:info, nil, String) # Любое сообщение

    # Мок Telegram::Bot::Client
    # ...
  end
end
```

---

## Сводка изменений по файлам

| Файл | Действие | Сложность |
|---|---|---|
| `config/app_config.rb` | Добавить параметры (5 новых) | 🟢 Легко |
| `lib/polling_starter.rb` | Создать новый файл | 🟢 Легко |
| `lib/webhook_starter.rb` | Создать новый файл | 🟡 Средне |
| `lib/bot_launcher.rb` | Создать новый файл | 🟢 Легко |
| `lib/telegram_bot_handler.rb` | Рефакторинг методов | 🟡 Средне |
| `bot.rb` | Изменить запуск (3 строки) | 🟢 Легко |
| `.env.example` | Добавить переменные | 🟢 Легко |
| `README.md` | Добавить документацию | 🟢 Легко |
| `test/test_bot_launcher.rb` | Создать новый файл | 🟡 Средне |
| `test/test_polling_starter.rb` | Создать новый файл | 🟢 Легко |
| `test/test_webhook_starter.rb` | Создать новый файл | 🟡 Средне |

**Общая сложность**: 🟡 **Средняя** (примерно 4-6 часов для опытного разработчика)

---

## Последовательность выполнения

1. **Обновить AppConfig** - добавить новые параметры
2. **Создать PollingStarter** - простой wraper текущей логики
3. **Создать WebhookStarter** - сложный HTTP сервер
4. **Создать BotLauncher** - фабрика для выбора стартера
5. **Рефакторить TelegramBotHandler** - сделать handle_update
6. **Обновить bot.rb** - использовать BotLauncher
7. **Написать тесты** - для новых компонентов
8. **Обновить документацию** - README.md и .env.example

---

## Возможные проблемы и решения

### Проблема 1: Webhook требует HTTPS
**Решение**: Использовать SSL сертификат (self-signed для тестирования)

### Проблема 2: Telegram требует ответ в течение 30 секунд
**Решение**: Асинхронная обработка длительных операций (Future/Promise)

### Проблема 3: Разные способы отправки сообщений (polling vs webhook)
**Решение**: Инкапсулировать отправку в отдельный метод `send_message`

### Проблема 4: Сложность тестирования webhook режима
**Решение**: Мокировать HTTP сервер и Telegram API в тестах

---

## Дополнительные улучшения (Future)

- [ ] Автоматическое переключение polling↔webhook при ошибках
- [ ] Prometheus метрики для обоих режимов
- [ ] Health checks для webhook (мониторинг соединения)
- [ ] Graceful shutdown для webhook сервера
- [ ] Docker поддержка с готовыми конфигурациями
- [ ] Поддержка multiple webhook URLs для высокой доступности
