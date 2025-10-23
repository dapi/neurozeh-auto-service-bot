# Debug Logging для Claude API

В этом проекте добавлена возможность детального логирования HTTP запросов к Claude API для помощи в отладке ошибок.

## Включение Debug логирования

Для включения debug логирования установите переменную окружения `DEBUG_API_REQUESTS=true`:

```bash
export DEBUG_API_REQUESTS=true
ruby bot.rb
```

Или добавьте в `.env` файл:
```
DEBUG_API_REQUESTS=true
```

## Что логируется

При включенном debug режиме будут логироваться:

1. **Детальная информация о запросах**:
   - URL запроса
   - HTTP метод
   - Заголовки (включая Authorization)
   - Тело запроса в формате JSON

2. **Детальная информация об ответах**:
   - HTTP статус код
   - Заголовки ответа
   - Тело ответа в формате JSON

3. **Дополнительная информация при ошибках**:
   - Полный объект ответа
   - Заголовки ответа
   - Raw тело ответа

## Пример лога

```
I, [2025-10-23T22:45:30.123456 #12345]  INFO -- : Request: POST https://api.z.ai/api/anthropic
I, [2025-10-23T22:45:30.123456 #12345]  INFO -- : Headers: {"Authorization"=>"Bearer Bearer token", "Content-Type"=>"application/json"}
I, [2025-10-23T22:45:30.123456 #12345]  INFO -- : Body: {"model":"glm-4.5-air","max_tokens":1500,"system":"...","messages":[{"role":"user","content":"Hello"}]}
I, [2025-10-23T22:45:31.654321 #12345]  INFO -- : Response: Status 200, Headers: {"Content-Type"=>"application/json"}, Body: {"content":[{"text":"Response text"}]}
```

## Использование в коде

```ruby
# В ClaudeClient
config = AppConfig.new
config.debug_api_requests  # => true/false

client = ClaudeClient.new(config, logger)
# Если debug_api_requests = true, будет использоваться detailed_logger
# Если debug_api_requests = false, будет использоваться обычный logger
```

## Техническая реализация

- Используется гем `faraday-detailed_logger` для детального логирования
- Логирование включается через middleware в Faraday connection
- При ошибке `404 NOT_FOUND` или других ошибках API, будет выведена подробная информация для диагностики

## Безопасность

**Важно**: При включенном debug логировании в логи попадают чувствительные данные, включая:
- API токены в заголовках Authorization
- Полное содержимое запросов и ответов

Используйте debug логирование только в разработческой среде и никогда не выгружайте логи с включенным debug режимом в продакшн!