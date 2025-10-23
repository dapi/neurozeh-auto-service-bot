# Кузник Бот - Telegram Bot для Записи на Авто-Услуги

Telegram бот для записи на услуги автосервиса с интеграцией Claude AI.

## Описание проекта

Бот использует Claude AI от Anthropic для обработки запросов пользователей и ведения диалогов о услугах автосервиса. Бот отслеживает истории диалогов каждого пользователя и имеет защиту от спама через Rate Limiter.

## Требования

- Ruby >= 3.2.0
- Telegram Bot Token (получить можно у [@BotFather](https://t.me/botfather))
- Anthropic API Key (получить можно на [platform.anthropic.com](https://console.anthropic.com))

## Быстрый старт

### 1. Клонировать репозиторий и установить зависимости

```bash
git clone <repository>
cd kuznik-bot
bundle install
```

### 2. Настроить переменные окружения

Скопируй `.env.example` в `.env` и заполни необходимые значения:

```bash
cp .env.example .env
```

Отредактируй `.env`:

```
ANTHROPIC_AUTH_TOKEN=your_anthropic_api_key
TELEGRAM_BOT_TOKEN=your_telegram_bot_token
ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic
ANTHROPIC_MODEL=glm-4.5-air
SYSTEM_PROMPT_PATH=./system-prompt.md
RATE_LIMIT_REQUESTS=10
RATE_LIMIT_PERIOD=60
MAX_HISTORY_SIZE=10
LOG_LEVEL=info
```

### 3. Запустить бота

```bash
ruby bot.rb
```

## Архитектура приложения

```
┌─────────────────┐
│  Telegram User  │
└────────┬────────┘
         │
         │ Message
         ▼
┌──────────────────────────┐
│  TelegramBotHandler      │
│  - Слушает обновления    │
│  - Обрабатывает команды  │
└──────────┬───────────────┘
           │
           ├──▶ RateLimiter
           │    - Защита от спама
           │
           ├──▶ ConversationManager
           │    - Хранит историю диалогов
           │    - Последние 10 сообщений
           │
           └──▶ ClaudeClient
                - Отправляет запросы в Claude API
                - Обработка ошибок + 1 retry
                - Использует системный промпт
```

## Компоненты (ФАЗА 1)

### RateLimiter (`lib/rate_limiter.rb`)

Защита от спама. Ограничивает количество запросов для каждого пользователя:
- По умолчанию: 10 запросов за 60 секунд
- In-memory счетчик с автоматической очисткой старых записей

### ConversationManager (`lib/conversation_manager.rb`)

Управление историей диалогов:
- Хранит историю сообщений для каждого пользователя
- Сохраняет последние 10 сообщений (легко настроить)
- Полная очистка при команде `/start`
- Thread-safe с использованием Mutex

### ClaudeClient (`lib/claude_client.rb`)

HTTP клиент для общения с Claude API:
- Загружает системный промпт из файла
- Отправляет сообщения с контекстом диалога
- Простая обработка ошибок с 1 retry попыткой
- Парсинг JSON ответов

### TelegramBotHandler (`lib/telegram_bot_handler.rb`)

Основная логика бота:
- Слушает обновления от Telegram API
- Обрабатывает команду `/start` (очистка истории)
- Проверяет RateLimiter перед обработкой
- Отправляет запросы к Claude и возвращает ответы
- Логирует все события

### AppConfig (`config/app_config.rb`)

Управление конфигурацией через `anyway_config`:
- Загружает переменные из `.env` файла
- Валидирует обязательные параметры
- Предоставляет значения по умолчанию

## Переменные окружения

| Переменная | Описание | Обязательная | По умолчанию |
|---|---|---|---|
| `ANTHROPIC_AUTH_TOKEN` | API ключ Anthropic | ✅ | - |
| `ANTHROPIC_BASE_URL` | URL Anthropic API | ❌ | `https://api.z.ai/api/anthropic` |
| `ANTHROPIC_MODEL` | Модель Claude | ❌ | `glm-4.5-air` |
| `SYSTEM_PROMPT_PATH` | Путь к системному промпту | ❌ | `./system-prompt.md` |
| `TELEGRAM_BOT_TOKEN` | Token Telegram бота | ✅ | - |
| `PRICE_LIST_PATH` | Путь к прайс-листу CSV | ❌ | `./data/кузник.csv` |
| `RATE_LIMIT_REQUESTS` | Кол-во запросов в лимите | ❌ | `10` |
| `RATE_LIMIT_PERIOD` | Период лимита (в сек) | ❌ | `60` |
| `MAX_HISTORY_SIZE` | Макс. размер истории | ❌ | `10` |
| `LOG_LEVEL` | Уровень логирования | ❌ | `info` |

## Файловая структура

```
.
├── Gemfile                    # Зависимости проекта
├── Gemfile.lock              # Зафиксированные версии
├── Rakefile                  # Rake задачи (тесты)
├── README.md                 # Этот файл
├── .env.example              # Пример конфигурации
├── .gitignore                # Git исключения
├── bot.rb                    # Точка входа бота
├── system-prompt.md          # Системный промпт для Claude
│
├── config/
│   └── app_config.rb         # Конфигурация приложения
│
├── lib/
│   ├── claude_client.rb      # HTTP клиент для Claude API
│   ├── telegram_bot_handler.rb # Обработка Telegram сообщений
│   ├── conversation_manager.rb # Управление историей диалогов
│   └── rate_limiter.rb       # Защита от спама
│
├── test/
│   ├── test_helper.rb        # Конфиг для тестов
│   ├── test_rate_limiter.rb
│   ├── test_claude_client.rb
│   ├── test_conversation_manager.rb
│   └── test_app_config.rb
│
├── .protocols/
│   └── plan.md               # Детальный план реализации
│
└── data/
    └── кузник.csv            # Прайс-лист услуг
```

## Интеграция с прайс-листом

Бот автоматически загружает прайс-лист из CSV файла и использует его для:
- Определения категорий услуг
- Расчета стоимости по классам автомобилей
- Предложения дополнительных услуг

### Путь к прайс-листу

Путь к файлу прайс-листа настраивается через переменную окружения `PRICE_LIST_PATH`:
- По умолчанию: `./data/кузник.csv`
- Формат: CSV с UTF-8 кодировкой
- Файл должен существовать и быть читаемым при запуске приложения

### Валидация конфигурации

Приложение использует anyway_config для валидации всех параметров при запуске:
- Обязательные параметры проверяются автоматически
- Файловые пути проверяются на существование и читаемость
- Числовые параметры проверяются на корректность значений
- Режим работы бота проверяется на валидность

## Использование системного промпта

Системный промпт загружается из файла `system-prompt.md` и комбинируется с отформатированным прайс-листом. Это позволяет задать контекст и поведение бота для обработки запросов о услугах автосервиса с актуальными ценами.

Формат запроса к API:

```json
{
  "model": "glm-4.5-air",
  "max_tokens": 1500,
  "system": "Содержимое системного промпта + отформатированный прайс-лист...",
  "messages": [
    {"role": "user", "content": "Первое сообщение"},
    {"role": "assistant", "content": "Ответ Claude"},
    ...
  ]
}
```

## Тесты

Запуск всех тестов:

```bash
rake test
```

Тесты покрывают:
- RateLimiter (6 тестов)
- ConversationManager (7 тестов)
- ClaudeClient (3 теста)
- AppConfig (5 тестов)

Итого: 21 unit тест

## Обработка ошибок

Бот имеет встроенную обработку ошибок:
- Ошибки API Claude: простой rescue блок + 1 retry попытка
- Ошибки Telegram API: обработка с отправкой сообщения об ошибке
- Все ошибки логируются с уровнем `error` или `warn`

## Следующие шаги (ФАЗА 2)

После успешного запуска MVP, планируется добавить:

- MessageHandlers с паттерном Strategy
- TokenManager с точным подсчетом токенов
- Circuit Breaker для отказоустойчивости
- StructuredLogger для JSON логирования
- AsyncMessageProcessor для неблокирующей обработки
- Metrics и health checks
- Prompt caching для оптимизации стоимости
- Graceful shutdown

Детали см. в `.protocols/plan.md` и `.protocols/plan-must-have.md`

## Лицензия

MIT

## Контакты

Для вопросов и предложений обратитесь к разработчику.
