# Спецификация: Поддержка режимов Polling и Webhook

## 1. Обзор

Бот должен поддерживать два способа получения обновлений от Telegram:

### Режим 1: Polling (опрос)
- Бот активно опрашивает Telegram API на предмет новых сообщений
- Используется метод `getUpdates`
- Подходит для локальной разработки и нестабильных интернет-соединений
- Менее экономен по ресурсам, но проще в настройке

### Режим 2: Webhook (вебхук)
- Telegram отправляет обновления на адрес вашего сервера
- Сервер получает HTTPS POST запросы с обновлениями
- Более эффективен для production
- Требует регистрации вебхука и наличия HTTPS сертификата

## 2. Архитектура решения

### Структура компонентов

```
┌──────────────────────────────┐
│     AppConfig (updated)      │
│  - bot_mode: polling/webhook │
│  - webhook_url               │
│  - webhook_port              │
│  - webhook_host              │
│  - webhook_path              │
└──────────────────────────────┘
              │
              ▼
┌──────────────────────────────┐
│    BotLauncher (новый)      │
│  - Выбирает режим            │
│  - Инициирует стартер        │
└──────────────────────────────┘
              │
      ┌───────┴────────┐
      ▼                ▼
 ┌─────────────┐  ┌──────────────┐
 │PollingStart │  │WebhookStarter│
 │ - Запускает │  │ - Регистрирует│
 │   listener  │  │   вебхук     │
 │ - Слушает   │  │ - Запускает  │
 │   обновления│  │   HTTP сервер│
 └─────────────┘  └──────────────┘
      │                 │
      └─────────┬───────┘
                ▼
    ┌──────────────────────┐
    │TelegramBotHandler    │
    │(без изменений)       │
    └──────────────────────┘
```

## 3. Конфигурация

### Новые переменные окружения

```
BOT_MODE=polling              # или 'webhook'
WEBHOOK_URL=https://example.com
WEBHOOK_PORT=3000
WEBHOOK_HOST=0.0.0.0
WEBHOOK_PATH=/telegram/webhook
```

### Значения по умолчанию

| Переменная | Значение по умолчанию |
|---|---|
| BOT_MODE | polling |
| WEBHOOK_PORT | 3000 |
| WEBHOOK_HOST | 0.0.0.0 |
| WEBHOOK_PATH | /telegram/webhook |
| WEBHOOK_URL | (обязательна для webhook режима) |

## 4. Компоненты для реализации

### 4.1 BotLauncher (`lib/bot_launcher.rb`)
**Ответственность**: Выбор и инициация стартера на основе конфигурации

**Методы**:
- `initialize(config, logger)`
- `start()` - выбирает PollingStarter или WebhookStarter
- `private def launcher_for(mode)` - фабрика

**Логика**:
```ruby
case config.bot_mode
when 'webhook'
  WebhookStarter.new(...).start
when 'polling'
  PollingStarter.new(...).start
else
  raise ConfigError
end
```

### 4.2 PollingStarter (`lib/polling_starter.rb`)
**Ответственность**: Инициация polling режима

**Методы**:
- `initialize(config, logger, telegram_bot_handler)`
- `start()` - запускает слушание

**Логика**:
- Используется текущая логика `TelegramBotHandler.start`
- Просто делегирует вызов к telegram_bot_handler

### 4.3 WebhookStarter (`lib/webhook_starter.rb`)
**Ответственность**: Инициация webhook режима

**Методы**:
- `initialize(config, logger, telegram_bot_handler)`
- `start()` - регистрирует вебхук и запускает HTTP сервер
- `private def setup_webhook()` - регистрирует вебхук в Telegram API
- `private def start_http_server()` - запускает WEBrick/Puma
- `private def handle_webhook_request(params)` - обрабатывает входящие обновления

**Зависимости**:
- `webrick` или `puma` (HTTP сервер)
- `telegram/bot` (для регистрации вебхука)

**Логика**:
1. Регистрирует вебхук в Telegram API через `setWebhook`
2. Запускает HTTP сервер на заданном порту
3. При получении POST запроса на `/telegram/webhook`:
   - Парсит JSON тело
   - Конвертирует в объект Update
   - Делегирует TelegramBotHandler

## 5. Изменения в существующих компонентах

### AppConfig
- Добавить параметры: `bot_mode`, `webhook_url`, `webhook_port`, `webhook_host`, `webhook_path`
- Добавить валидацию: если `bot_mode == 'webhook'`, то `webhook_url` обязателен

### TelegramBotHandler
- Переименовать `start()` на `handle_polling()`
- Или извлечь логику polling в отдельный метод
- Добавить метод `handle_update(update)` для обработки одного обновления

### bot.rb (главная точка входа)
- Заменить вызов `telegram_bot_handler.start` на `BotLauncher.start`

## 6. Логирование

Каждый стартер должен логировать:

**PollingStarter**:
```
Polling mode started
Listening for updates...
```

**WebhookStarter**:
```
Webhook mode started
Registering webhook: https://example.com/telegram/webhook
Webhook registered successfully
Starting HTTP server on 0.0.0.0:3000
Listening for webhook requests on /telegram/webhook
```

## 7. Обработка ошибок

### PollingStarter
- Обработка сетевых ошибок (retry с backoff)
- Логирование исключений

### WebhookStarter
- Ошибка при регистрации вебхука → логирование + exit
- HTTP сервер ошибки → логирование
- Невалидный JSON → логирование + 400 response
- Подвеска вебхука от Telegram → переключение на polling (опционально)

## 8. Тестирование

### Unit тесты

**test_bot_launcher.rb**:
- ✅ Выбор PollingStarter для mode='polling'
- ✅ Выбор WebhookStarter для mode='webhook'
- ✅ Ошибка для неизвестного режима

**test_polling_starter.rb**:
- ✅ Инициализация
- ✅ Вызов telegram_bot_handler.start

**test_webhook_starter.rb**:
- ✅ Регистрация вебхука (мок Telegram API)
- ✅ Запуск HTTP сервера
- ✅ Обработка POST запроса с обновлением
- ✅ Обработка невалидного JSON (400 response)

### Integration тесты
- Запуск в polling режиме
- Запуск в webhook режиме
- Переключение режимов (опционально)

## 9. Безопасность (для webhook режима)

1. **HTTPS сертификат**: Telegram требует HTTPS для вебхуков
   - Self-signed сертификаты допускаются для тестирования
   - Production требует валидного сертификата

2. **Валидация источника**:
   - Проверка, что запрос идет от Telegram IP (опционально)
   - Логирование всех входящих запросов

3. **Timeout для запросов**:
   - Telegram ожидает ответ в течение 30 секунд
   - Если боту требуется больше времени → асинхронная обработка

## 10. Миграция для пользователей

### Документация
- Обновить README.md с новыми переменными окружения
- Добавить примеры конфигурации для обоих режимов
- Инструкции по регистрации вебхука

### Примеры запуска

**Polling режим** (по умолчанию):
```bash
ruby bot.rb
```

**Webhook режим**:
```bash
export BOT_MODE=webhook
export WEBHOOK_URL=https://example.com
export WEBHOOK_PORT=3000
ruby bot.rb
```

## 11. Фазовость реализации

### Фаза 1: Основная функциональность
- [ ] BotLauncher
- [ ] PollingStarter (wrap существующей логики)
- [ ] WebhookStarter с WEBrick
- [ ] Обновить AppConfig
- [ ] Обновить bot.rb
- [ ] Unit тесты

### Фаза 2: Оптимизация и улучшения
- [ ] Integration тесты
- [ ] Graceful shutdown для webhook
- [ ] Обработка ошибок и retry логика
- [ ] Metrics для обоих режимов

### Фаза 3: Production readiness
- [ ] Документация
- [ ] Docker поддержка
- [ ] Health checks
- [ ] Prometheus метрики
