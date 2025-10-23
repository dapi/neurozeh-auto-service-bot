# План имплементации Telegram бота с Claude API

> **Примечание:** Детальный план Must Have компонентов находится в `.protocols/plan-must-have.md`

## Приоритизация по фазам

### ФАЗА 1: MVP (Minimal Viable Product)
Минимальный набор для быстрого запуска работающего бота

1. ✅ Простая обработка сообщений (без Strategy Pattern)
2. ✅ RateLimiter для защиты от спама
3. ✅ Валидация конфигурации через anyway_config
4. ✅ Простое логирование (Ruby Logger)
5. ✅ Простое ограничение контекста (last N сообщений)
6. ✅ Простая обработка ошибок API (rescue + 1 retry)

### ФАЗА 2: Production Ready (расширение MVP)
Компоненты для production использования и надежности

- MessageHandlers с паттерном Strategy
- TokenManager с точным подсчетом токенов
- Circuit Breaker для отказоустойчивости
- StructuredLogger для JSON логирования
- AsyncMessageProcessor для неблокирующей обработки
- Metrics и health checks
- Prompt caching для оптимизации стоимости
- Graceful shutdown

---

## 1. Подготовка проекта

- [ ] 1.1 Инициализировать Ruby проект (структура директорий)
- [ ] 1.1.1 Создать файл system-prompt.md в корне проекта (системный промпт для Claude)
- [ ] 1.2 Создать Gemfile с необходимыми зависимостями
  - [ ] 1.2.1 telegram-bot-ruby
  - [ ] 1.2.2 httparty
  - [ ] 1.2.3 dotenv
  - [ ] 1.2.4 anyway_config (управление конфигурацией)
  - [ ] 1.2.5 Другие необходимые gems
- [ ] 1.3 Запустить `bundle install`
- [ ] 1.4 Создать конфигурацию anyway_config:
  - [ ] 1.4.1 Создать файл config/app_config.rb с настройками для claude_client и telegram_bot_handler
- [ ] 1.5 Создать .gitignore (исключить .env и временные файлы)

## 2. Структура приложения

### 2.1 Базовые директории и классы

- [ ] 2.1.1 Создать директорию `lib/`
- [ ] 2.1.2 Создать директорию `lib/message_handlers/`

### 2.2 ФАЗА 1: MVP компоненты

#### 2.2.1 ClaudeClient (упрощенный)
- [ ] 2.2.1.1 Создать класс `ClaudeClient` (lib/claude_client.rb)
  - [ ] 2.2.1.1.1 Инициализация с конфигурацией (через anyway_config):
    - [ ] ANTHROPIC_BASE_URL
    - [ ] ANTHROPIC_AUTH_TOKEN
    - [ ] ANTHROPIC_MODEL
    - [ ] SYSTEM_PROMPT_PATH (по-умолчанию: ./system-prompt.md)
  - [ ] 2.2.1.1.2 Загрузка системного промпта из файла
  - [ ] 2.2.1.1.3 Метод для отправки сообщений в Claude API (с системным промптом в параметре `system`)
  - [ ] 2.2.1.1.4 Простая обработка ошибок API (rescue блок + 1 retry попытка)
  - [ ] 2.2.1.1.5 Простое логирование через Ruby Logger

#### 2.2.2 RateLimiter (упрощенный)
- [ ] 2.2.2.1 Создать `lib/rate_limiter.rb`
- [ ] 2.2.2.2 Простой in-memory счетчик запросов (user_id => [timestamps])
- [ ] 2.2.2.3 Метод `allow?(user_id)` для проверки лимита
- [ ] 2.2.2.4 Защита от спама (по-умолчанию: 10 запросов за 60 секунд)

#### 2.2.3 Валидация конфигурации
- [ ] 2.2.3.1 Обновить `config/app_config.rb`
- [ ] 2.2.3.2 Метод `validate!()` с проверками обязательных параметров
- [ ] 2.2.3.3 Значения по-умолчанию для параметров
- [ ] 2.2.3.4 Использование anyway_config для управления конфигурацией

#### 2.2.4 TelegramBotHandler (упрощенный)

- [ ] 2.2.4.1 Создать класс `TelegramBotHandler` (lib/telegram_bot_handler.rb)
  - [ ] 2.2.4.1.1 Инициализация с конфигурацией (TELEGRAM_BOT_TOKEN через anyway_config)
  - [ ] 2.2.4.1.2 Инициализация с RateLimiter для защиты от спама
  - [ ] 2.2.4.1.3 Инициализация с ConversationManager
  - [ ] 2.2.4.1.4 Слушание обновлений от Telegram
  - [ ] 2.2.4.1.5 Простая обработка сообщений (if/case без Strategy Pattern)
  - [ ] 2.2.4.1.6 Проверка RateLimiter перед обработкой
  - [ ] 2.2.4.1.7 Логирование через Ruby Logger

#### 2.2.5 ConversationManager (упрощенный)

- [ ] 2.2.5.1 Создать класс `ConversationManager` (lib/conversation_manager.rb)
  - [ ] 2.2.5.1.1 In-memory хранилище истории сообщений
  - [ ] 2.2.5.1.2 Метод get_history(user_id) для получения истории
  - [ ] 2.2.5.1.3 Метод add_message(user_id, role, content) для добавления сообщения
  - [ ] 2.2.5.1.4 Метод clear_history(user_id) для очистки (команда /start)
  - [ ] 2.2.5.1.5 Ограничение контекста: сохранять только последние 10 сообщений
  - [ ] 2.2.5.1.6 TTL для автоматической очистки старых диалогов (опционально)

## 3. Интеграция Claude API (ФАЗА 1)

Реализуется в ClaudeClient с простой обработкой ошибок.

- [ ] 3.1 HTTP запросы к Claude API
  - [ ] 3.1.1 Формирование заголовков (Authorization, content-type)
  - [ ] 3.1.2 Подготовка тела запроса (model, messages, system, max_tokens)
  - [ ] 3.1.3 HTTP POST запрос через HTTParty

- [ ] 3.2 Обработка ответов от API
  - [ ] 3.2.1 Парсинг JSON ответа
  - [ ] 3.2.2 Извлечение текста из response

- [ ] 3.3 Обработка ошибок (простая)
  - [ ] 3.3.1 Rescue блок для всех типов ошибок
  - [ ] 3.3.2 1 retry попытка при временных ошибках
  - [ ] 3.3.3 Логирование ошибки с уровнем error

## 4. Интеграция Telegram (ФАЗА 1)

Реализуется в TelegramBotHandler с простой обработкой.

- [ ] 4.1 Слушатель сообщений
  - [ ] 4.1.1 Запуск слушателя обновлений от Telegram

- [ ] 4.2 Обработка входящих сообщений
  - [ ] 4.2.1 Получение текста сообщения
  - [ ] 4.2.2 Проверка RateLimiter

- [ ] 4.3 Поддерживаемые команды
  - [ ] 4.3.1 `/start` - очистка истории диалога

- [ ] 4.4 Отправка ответов пользователю
  - [ ] 4.4.1 Форматирование текста для Telegram
  - [ ] 4.4.2 Отправка через Telegram API

## 5. Создание точки входа приложения (ФАЗА 1)

- [ ] 5.1 Создать файл `bot.rb` в корне проекта (точка входа)
  - [ ] 5.1.1 Загрузка Gemfile зависимостей
  - [ ] 5.1.2 Загрузка конфигурации через AppConfig
  - [ ] 5.1.3 Валидация конфигурации
  - [ ] 5.1.4 Инициализация Ruby Logger

- [ ] 5.2 Инициализировать компоненты в порядке:
  - [ ] 5.2.1 RateLimiter
  - [ ] 5.2.2 ClaudeClient
  - [ ] 5.2.3 ConversationManager
  - [ ] 5.2.4 TelegramBotHandler

- [ ] 5.3 Запустить бота
  - [ ] 5.3.1 Логирование информации о запуске
  - [ ] 5.3.2 Начало слушания Telegram обновлений

- [ ] 5.4 Обработка сигналов
  - [ ] 5.4.1 Обработка SIGINT (Ctrl+C)

## 6. Документация и конфигурация (ФАЗА 1)

- [ ] 6.1 Создать/обновить README.md
  - [ ] 6.1.1 Описание проекта и его назначения
  - [ ] 6.1.2 Требования (Ruby версия, зависимости)
  - [ ] 6.1.3 Ссылка на `.protocols/plan.md` и `.protocols/plan-must-have.md` для деталей реализации
  - [ ] 6.1.4 Переменные окружения:
    - [ ] ANTHROPIC_BASE_URL
    - [ ] ANTHROPIC_AUTH_TOKEN
    - [ ] ANTHROPIC_MODEL
    - [ ] SYSTEM_PROMPT_PATH (по-умолчанию: ./system-prompt.md)
    - [ ] TELEGRAM_BOT_TOKEN
    - [ ] Дополнительные параметры лимитов и timeouts
  - [ ] 6.1.5 Инструкции по быстрому старту
  - [ ] 6.1.6 Архитектура приложения (диаграмма компонентов)
  - [ ] 6.1.7 Описание Must Have компонентов

- [ ] 6.2 Создать `.env.example` файл с примерами всех переменных
- [ ] 6.3 Обновить `.gitignore` (исключить .env, temp файлы)
- [ ] 6.4 Обработка исключений с логированием (реализовано в Must Have компонентах)

## 7. Unit-тесты с minitest (ФАЗА 1)

Минимальное тестовое покрытие критических компонентов.

- [ ] 7.1 Подготовка тестового окружения
  - [ ] 7.1.1 Добавить minitest в Gemfile
  - [ ] 7.1.2 Создать директорию `test/`
  - [ ] 7.1.3 Создать файл `test/test_helper.rb`

- [ ] 7.2 Unit-тесты основных компонентов
  - [ ] 7.2.1 Тесты RateLimiter (5-6 тестов)
  - [ ] 7.2.2 Тесты ClaudeClient (4-5 тестов)
  - [ ] 7.2.3 Тесты ConversationManager (3-4 теста)
  - [ ] 7.2.4 Тесты AppConfig (2-3 теста)
  - [ ] Итого: ~15 unit тестов

- [ ] 7.3 Интеграционное тестирование (ручное)
  - [ ] 7.3.1 Тест с реальным ботом: текст → Claude → ответ
  - [ ] 7.3.2 Тест команды /start
  - [ ] 7.3.3 Тест rate limiting

- [ ] 7.4 Rake task для тестов
  - [ ] 7.4.1 Добавить `rake test` в Rakefile

## 8. Manual тестирование (ФАЗА 1)

- [ ] 8.1 Базовая функциональность
  - [ ] 8.1.1 Отправить текстовое сообщение боту
  - [ ] 8.1.2 Проверить получение ответа от Claude
  - [ ] 8.1.3 Проверить логирование

- [ ] 8.2 Команды
  - [ ] 8.2.1 Отправить `/start` - очистка истории

- [ ] 8.3 Контекст диалога
  - [ ] 8.3.1 Отправить несколько сообщений подряд
  - [ ] 8.3.2 Проверить что Claude помнит контекст
  - [ ] 8.3.3 После `/start` контекст новый

- [ ] 8.4 Rate limiting
  - [ ] 8.4.1 Отправить 10+ быстрых сообщений
  - [ ] 8.4.2 Проверить что лишние отклоняются

## Примечания к реализации системного промпта

### Формат запроса к Anthropic API

Системный промпт передается как параметр `system` на верхнем уровне запроса:

```json
{
  "model": "claude-3-5-sonnet-20241022",
  "max_tokens": 1024,
  "system": "Содержимое системного промпта из файла",
  "messages": [
    {"role": "user", "content": "Первое сообщение"},
    {"role": "assistant", "content": "Ответ Claude"},
    {"role": "user", "content": "Второе сообщение"}
  ]
}
```

### Реализация в Ruby с HTTParty

```ruby
def send_message(messages)
  body = {
    model: @config.anthropic_model,
    max_tokens: 1024,
    system: @system_prompt,  # Загруженный системный промпт
    messages: messages
  }

  response = HTTParty.post(
    @config.anthropic_base_url,
    headers: { 'Authorization' => "Bearer #{@config.anthropic_auth_token}" },
    body: body.to_json,
    format: :json
  )
end
```

## Файловая структура после ФАЗА 1 (MVP)

```
.
├── Gemfile
├── Gemfile.lock
├── Rakefile
├── README.md
├── .env.example
├── .gitignore
├── .protocols/
│   └── plan.md (этот файл)
├── bot.rb (точка входа, ~50 строк)
├── system-prompt.md (системный промпт для Claude)
│
├── config/
│   └── app_config.rb (конфигурация с anyway_config)
│
├── lib/
│   ├── claude_client.rb (простой HTTP клиент + 1 retry)
│   ├── telegram_bot_handler.rb (обработка сообщений + простой if/case)
│   ├── conversation_manager.rb (in-memory история, last 10 сообщений)
│   └── rate_limiter.rb (простая защита от спама)
│
├── test/
│   ├── test_helper.rb
│   ├── test_rate_limiter.rb
│   ├── test_claude_client.rb
│   ├── test_conversation_manager.rb
│   └── test_app_config.rb
│
└── data/
    └── кузник.csv
```

## Итого ФАЗА 1 (MVP):

**5 файлов класса:**
- `lib/claude_client.rb` - простой HTTP клиент
- `lib/telegram_bot_handler.rb` - основная логика бота
- `lib/conversation_manager.rb` - in-memory история
- `lib/rate_limiter.rb` - защита от спама
- `config/app_config.rb` - конфигурация через anyway_config

**5 файлов тестов:**
- `test/test_rate_limiter.rb`
- `test/test_claude_client.rb`
- `test/test_conversation_manager.rb`
- `test/test_app_config.rb`
- `test/test_helper.rb`

**Всего:**
- ~500 строк кода (вместо ~1200)
- ~15 unit тестов (вместо 52)
- Можно реализовать за 1-2 дня
- Easy to understand и extend

**Что убрали до ФАЗЫ 2:**
- MessageHandlers Strategy Pattern
- TokenManager (используем `messages.last(10)`)
- Circuit Breaker (используем простой rescue + retry)
- StructuredLogger (используем Ruby Logger)
- SystemPromptLoader класс (просто читаем файл в ClaudeClient)
