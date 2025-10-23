# Примеры использования: Polling vs Webhook режимы

## 1. Сравнение режимов

### Polling режим (текущий)

```
Telegram ← Telegram ← Telegram
   ↑        ↑         ↑
   |        |         |
   +---────────────────+
        (getUpdates
         каждые 30s)

Bot (опрашивает каждые 30 сек)
```

**Временная шкала**:
```
[0s]   Bot: getUpdates?
       Telegram: нет обновлений

[30s]  Bot: getUpdates?
       Telegram: вот сообщение от пользователя
       Bot: обработал

[60s]  Bot: getUpdates?
       Telegram: нет обновлений
```

**Лучшее время ответа**: ~30 секунд (зависит от интервала опроса)

### Webhook режим (новый)

```
Telegram  ──────────→  Bot (HTTPS)
(instant)     POST
          ←──────────
          200 OK
```

**Временная шкала**:
```
[0ms]  Пользователь отправит сообщение
[1ms]  Telegram отправляет HTTPS POST запрос на бот
[10ms] Bot получил и обработал сообщение
[20ms] Bot отправляет ответ пользователю
```

**Лучшее время ответа**: ~20-30ms (почти моментально)

---

## 2. Примеры конфигурации и запуска

### Пример 1: Локальная разработка с Polling

```bash
# .env файл
BOT_MODE=polling
ANTHROPIC_AUTH_TOKEN=sk-...
TELEGRAM_BOT_TOKEN=123456:ABC...
LOG_LEVEL=debug

# Запуск
$ ruby bot.rb
Kuznik Bot starting...
Configuration loaded:
  - Anthropic Model: claude-3-5-sonnet-20241022
  - Rate Limit: 10 requests per 60 seconds
  - Max History Size: 10
RateLimiter initialized
ConversationManager initialized
ClaudeClient initialized
TelegramBotHandler initialized
BotLauncher initialized for mode: polling
Starting bot...
Polling mode started
Listening for updates from Telegram...
```

**Тест**:
```bash
# Отправьте сообщение боту в Telegram
# Bot получит его при следующем опросе (~30 сек)
```

---

### Пример 2: Production с Webhook

```bash
# .env файл
BOT_MODE=webhook
WEBHOOK_URL=https://mybot.example.com
WEBHOOK_PORT=3000
WEBHOOK_HOST=0.0.0.0
WEBHOOK_PATH=/telegram/webhook
ANTHROPIC_AUTH_TOKEN=sk-...
TELEGRAM_BOT_TOKEN=123456:ABC...
LOG_LEVEL=info

# Запуск
$ ruby bot.rb
Kuznik Bot starting...
Configuration loaded:
  - Anthropic Model: claude-3-5-sonnet-20241022
  - Rate Limit: 10 requests per 60 seconds
  - Max History Size: 10
RateLimiter initialized
ConversationManager initialized
ClaudeClient initialized
TelegramBotHandler initialized
BotLauncher initialized for mode: webhook
Starting bot...
Webhook mode started
Webhook URL: https://mybot.example.com
Server: 0.0.0.0:3000
Registering webhook with Telegram...
Webhook registered successfully: https://mybot.example.com/telegram/webhook
Starting HTTP server on 0.0.0.0:3000
Listening for webhook requests on /telegram/webhook
```

**Тест**:
```bash
# Отправьте сообщение боту в Telegram
# Bot получит его моментально через HTTPS POST

# Проверить статус вебхука
curl https://api.telegram.org/bot<TOKEN>/getWebhookInfo
# Ответ:
# {
#   "ok": true,
#   "result": {
#     "url": "https://mybot.example.com/telegram/webhook",
#     "has_custom_certificate": false,
#     "pending_update_count": 0,
#     "last_error_date": 0
#   }
# }
```

---

## 3. Примеры HTTP запросов/ответов (Webhook)

### Входящий запрос от Telegram

```http
POST /telegram/webhook HTTP/1.1
Host: mybot.example.com:3000
Content-Type: application/json
User-Agent: TelegramBot (like TwitterBot)
Content-Length: 345

{
  "update_id": 123456789,
  "message": {
    "message_id": 1,
    "date": 1697450000,
    "chat": {
      "id": 987654321,
      "type": "private",
      "first_name": "John"
    },
    "from": {
      "id": 987654321,
      "is_bot": false,
      "first_name": "John"
    },
    "text": "Привет! Хочу покрасить свою машину"
  }
}
```

### Ответ бота

```http
HTTP/1.1 200 OK
Content-Type: application/json
Content-Length: 20

{
  "ok": true
}
```

### Ошибка: неверный JSON

```http
POST /telegram/webhook HTTP/1.1
...
{not valid json
```

**Ответ**:
```http
HTTP/1.1 400 Bad Request
Content-Type: application/json
Content-Length: 49

{
  "ok": false,
  "error": "Invalid JSON"
}
```

### Ошибка: неверный метод

```http
GET /telegram/webhook HTTP/1.1
```

**Ответ**:
```http
HTTP/1.1 405 Method Not Allowed
Content-Type: application/json
Content-Length: 53

{
  "ok": false,
  "error": "Method not allowed"
}
```

---

## 4. Логи работы

### Polling режим - обычный день

```
[2024-10-23 10:00:00] INFO: Polling mode started
[2024-10-23 10:00:01] INFO: Listening for updates from Telegram...
[2024-10-23 10:01:15] INFO: Received message from user 987654321: Привет!...
[2024-10-23 10:01:15] INFO: Successfully processed message for user 987654321
[2024-10-23 10:02:30] INFO: Received message from user 987654321: Сколько стоит покраска?...
[2024-10-23 10:02:31] INFO: Successfully processed message for user 987654321
[2024-10-23 10:02:45] WARN: Rate limit exceeded for user 987654321
```

### Webhook режим - обычный день

```
[2024-10-23 10:00:00] INFO: Webhook mode started
[2024-10-23 10:00:00] INFO: Webhook URL: https://mybot.example.com
[2024-10-23 10:00:00] INFO: Server: 0.0.0.0:3000
[2024-10-23 10:00:01] INFO: Registering webhook with Telegram...
[2024-10-23 10:00:01] INFO: Webhook registered successfully: https://mybot.example.com/telegram/webhook
[2024-10-23 10:00:02] INFO: Starting HTTP server on 0.0.0.0:3000
[2024-10-23 10:00:02] INFO: Listening for webhook requests on /telegram/webhook
[2024-10-23 10:01:15] DEBUG: Received webhook request: {"update_id": 123456789, "message": {...
[2024-10-23 10:01:15] INFO: Received message from user 987654321: Привет!...
[2024-10-23 10:01:15] INFO: Successfully processed message for user 987654321
[2024-10-23 10:01:16] DEBUG: Webhook request processed successfully
[2024-10-23 10:02:30] DEBUG: Received webhook request: {"update_id": 123456790, "message": {...
[2024-10-23 10:02:30] INFO: Received message from user 987654321: Сколько стоит покраска?...
[2024-10-23 10:02:31] INFO: Successfully processed message for user 987654321
[2024-10-23 10:02:31] DEBUG: Webhook request processed successfully
```

---

## 5. Диагностика проблем

### Проблема: Webhook не работает в локальной сети

```bash
# Telegram требует HTTPS с валидным сертификатом
# Для локального тестирования используйте self-signed сертификат

# Генерация самоподписанного сертификата:
openssl req -x509 -newkey rsa:4096 -nodes \
  -out cert.pem -keyout key.pem -days 365

# Регистрация webhook с self-signed сертификатом:
curl -X POST \
  https://api.telegram.org/bot<TOKEN>/setWebhook \
  -F "url=https://your-ip:3000/telegram/webhook" \
  -F "certificate=@cert.pem"
```

### Проблема: Polling очень медленный

```ruby
# Текущие настройки в telegram-bot gem:
# timeout: 25 (секунд до следующего опроса)

# Для ускорения используйте short polling:
# Но это требует изменения в коде TelegramBotHandler

# Или просто переключитесь на Webhook режим
export BOT_MODE=webhook
```

### Проблема: Webhook не регистрируется

```bash
# Проверьте URL:
curl -X POST \
  https://api.telegram.org/bot<TOKEN>/getWebhookInfo

# Если есть ошибка - смотрите логи последней ошибки:
curl -X POST \
  https://api.telegram.org/bot<TOKEN>/getMe

# Проверьте, что сервер доступен:
curl -v https://your-domain.com/telegram/webhook

# Сброс вебхука:
curl -X POST \
  https://api.telegram.org/bot<TOKEN>/deleteWebhook
```

---

## 6. Производительность и затраты

### Polling режим

```
Requests/day:   ~2880 (1 запрос каждые 30 сек)
API calls:      2880 getUpdates
CPU usage:      Medium (постоянный опрос)
Latency:        30 секунд (в среднем)
```

### Webhook режим

```
Requests/day:   ~1000-5000 (в зависимости от нагрузки)
API calls:      0 (нет опроса)
CPU usage:      Low (пассивное слушание)
Latency:        20-100ms (мгновенно)
```

**Вывод**: Webhook значительно эффективнее для production!

---

## 7. Миграция с Polling на Webhook

### Шаг 1: Подготовка
```bash
# Убедитесь что у вас есть валидный HTTPS сертификат
# Получите доменное имя (или IP)
```

### Шаг 2: Обновить конфигурацию
```bash
export BOT_MODE=webhook
export WEBHOOK_URL=https://your-domain.com
```

### Шаг 3: Перезапустить бота
```bash
# Старый процесс (Ctrl+C):
^C
Received SIGINT, shutting down...

# Новый процесс:
$ ruby bot.rb
# ... логи показывают webhook регистрацию
```

### Шаг 4: Проверить
```bash
# Отправьте сообщение боту
# Проверьте что ответ пришел быстро (~1 сек вместо ~30 сек)

# Проверить статус вебхука:
curl https://api.telegram.org/bot<TOKEN>/getWebhookInfo
```

---

## 8. Docker примеры

### Dockerfile для Webhook режима

```dockerfile
FROM ruby:3.2-alpine

WORKDIR /app

COPY Gemfile Gemfile.lock ./
RUN bundle install --without development test

COPY . .

# Для webhook требуется HTTPS
COPY cert.pem /app/cert.pem
COPY key.pem /app/key.pem

ENV BOT_MODE=webhook
ENV WEBHOOK_PORT=3000

EXPOSE 3000

CMD ["ruby", "bot.rb"]
```

### docker-compose.yml

```yaml
version: '3.8'

services:
  kuznik-bot:
    build: .
    environment:
      BOT_MODE: webhook
      WEBHOOK_URL: https://mybot.example.com
      WEBHOOK_PORT: 3000
      ANTHROPIC_AUTH_TOKEN: ${ANTHROPIC_AUTH_TOKEN}
      TELEGRAM_BOT_TOKEN: ${TELEGRAM_BOT_TOKEN}
    ports:
      - "3000:3000"
    volumes:
      - ./cert.pem:/app/cert.pem:ro
      - ./key.pem:/app/key.pem:ro
    restart: always
```

### Запуск

```bash
docker-compose up -d
```

---

## 9. Чеклист для production запуска (Webhook)

- [ ] Получен валидный HTTPS сертификат (не self-signed)
- [ ] Доменное имя или IP зарегистрировано
- [ ] Firewall открыл порт 443/3000 для входящих соединений
- [ ] Bot в режиме webhook (`BOT_MODE=webhook`)
- [ ] WEBHOOK_URL указана корректно
- [ ] Проверена регистрация вебхука (`getWebhookInfo`)
- [ ] Логирование настроено (LOG_LEVEL=info)
- [ ] Мониторинг и алерты настроены
- [ ] Graceful shutdown обработан (SIGTERM)
- [ ] Rate limiting работает корректно
- [ ] Тестовое сообщение обработано успешно
- [ ] Health check эндпоинт готов

---

## 10. Особенности и ограничения

### Webhook ограничения от Telegram

1. **Timeout 30 секунд** - если не ответить в течение 30 сек, Telegram считает вебхук недоступным
2. **HTTPS обязателен** - HTTP не работает (кроме localhost)
3. **Max 100 одновременных вебхуков** - на одного бота одновременно
4. **Max 100 repeated errors** - после 100 ошибок вебхук отключается
5. **IP whitelist** - опционально можно ограничить IPs Telegram

### Polling ограничения

1. **Медленный ответ** - зависит от интервала опроса (обычно 25-30 сек)
2. **Высокое потребление API** - ~2880 запросов в день
3. **Задержка мессенджера** - на получение новых сообщений

---

## Итоговое сравнение

| Критерий | Polling | Webhook |
|---|---|---|
| Скорость ответа | ~30s | ~20-100ms |
| API calls/день | ~2880 | 0 |
| Сложность | 🟢 | 🟡 |
| HTTPS требуется | ❌ | ✅ |
| Доменное имя | ❌ | ✅ |
| CPU usage | 🟡 | 🟢 |
| Подходит для DEV | ✅ | ❌ |
| Подходит для PROD | ❌ | ✅ |
| Надежность | 🟡 | 🟢 |
| Цена Telegram API | 💰💰 | 💰 |

