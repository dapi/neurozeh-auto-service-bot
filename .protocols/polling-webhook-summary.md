# Краткий обзор: Поддержка Polling и Webhook режимов

## 📋 Суть

Реализовать возможность запуска бота в **двух режимах**:

1. **Polling** (текущий) - бот сам опрашивает Telegram каждые 30 сек
2. **Webhook** (новый) - Telegram отправляет обновления на сервер бота

---

## 🎯 Что нужно сделать

### Новые файлы (3 шт)

```
lib/
├── bot_launcher.rb        (фабрика для выбора режима)
├── polling_starter.rb     (стартер для polling)
└── webhook_starter.rb     (стартер для webhook + HTTP сервер)
```

### Обновленные файлы (4 шт)

```
config/app_config.rb        (добавить параметры bot_mode, webhook_url, etc.)
lib/telegram_bot_handler.rb (рефакторинг: добавить handle_update + send_message)
bot.rb                      (заменить telegram_bot_handler.start на launcher.start)
.env.example                (добавить новые переменные)
```

### Тест файлы (3 шт)

```
test/test_bot_launcher.rb
test/test_polling_starter.rb
test/test_webhook_starter.rb
```

---

## ⚡ Быстрый старт

### Polling режим (по умолчанию, ничего не меняется)
```bash
BOT_MODE=polling
ruby bot.rb
```

### Webhook режим (новый)
```bash
BOT_MODE=webhook
WEBHOOK_URL=https://mybot.example.com
WEBHOOK_PORT=3000
ruby bot.rb
```

---

## 📊 Сравнение

| | Polling | Webhook |
|---|---|---|
| Скорость | ~30 сек | ~20ms |
| API calls/день | 2880 | 0 |
| HTTPS | ❌ | ✅ |
| Production | ❌ | ✅ |

---

## 📁 Документация

Все документы находятся в `.protocols/`:

1. **polling-webhook-spec.md** - Полная спецификация (архитектура, API, требования)
2. **polling-webhook-implementation.md** - Пошаговый план имплементации (код, тесты)
3. **polling-webhook-examples.md** - Примеры, логи, диагностика
4. **polling-webhook-summary.md** - Этот файл (краткий обзор)

---

## 🔧 Архитектура (упрощенная)

```
┌─────────────────────┐
│  BotLauncher        │
│  - Выбирает режим   │
└──────────┬──────────┘
           │
    ┌──────┴─────┐
    ▼             ▼
┌─────────┐  ┌──────────┐
│Polling  │  │Webhook   │
│Starter  │  │Starter   │
└────┬────┘  └────┬─────┘
     │            │
     └──────┬─────┘
            ▼
    ┌──────────────────┐
    │TelegramBotHandler│
    │  handle_update() │
    └──────────────────┘
```

---

## 📝 Последовательность работ

1. ✅ Спецификация написана (polling-webhook-spec.md)
2. ✅ План имплементации готов (polling-webhook-implementation.md)
3. ✅ Примеры и диагностика есть (polling-webhook-examples.md)
4. ⏳ Готов к имплементации

---

## 🚀 Следующие шаги

1. Начать с **AppConfig** (добавить новые параметры)
2. Создать **PollingStarter** (простой wraper)
3. Создать **WebhookStarter** (более сложный)
4. Создать **BotLauncher** (фабрика)
5. Обновить **TelegramBotHandler** (handle_update)
6. Обновить **bot.rb** (использовать launcher)
7. Написать **тесты**
8. Обновить **README.md**

---

## 💡 Ключевые моменты

- **Polling режим** остается как fallback для локальной разработки
- **Webhook режим** подходит для production
- **Оба режима используют одинаковую логику обработки** (TelegramBotHandler)
- **Конфигурация управляется через .env** (BOT_MODE, WEBHOOK_URL, etc.)
- **Тестирование включает unit + integration тесты**

---

## 📚 Полезные ссылки

- [Telegram Bot API - getUpdates](https://core.telegram.org/bots/api#getupdates)
- [Telegram Bot API - setWebhook](https://core.telegram.org/bots/api#setwebhook)
- [Telegram Bot API - getWebhookInfo](https://core.telegram.org/bots/api#getwebhookinfo)

---

## ❓ FAQ

**Q: Почему нужны два режима?**
A: Polling для локальной разработки (нет HTTPS), Webhook для production (быстрее, эффективнее)

**Q: Можно ли переключаться между режимами?**
A: Да! Просто измените `BOT_MODE` в .env и перезапустите бота

**Q: Будут ли проблемы совместимости?**
A: Нет! Существующий код polling режима не изменится, webhook будет опциональный

**Q: Сколько времени займет?**
A: ~4-6 часов для опытного разработчика

**Q: Нужно ли менять код TelegramBotHandler?**
A: Минимально - только добавить методы `handle_update()` и `send_message()`

---

## ✨ Преимущества

1. ✅ Гибкость: выбор режима через .env
2. ✅ Простота: polling для разработки, webhook для production
3. ✅ Производительность: webhook в 150 раз быстрее
4. ✅ Надежность: webhook надежнее polling
5. ✅ Обратная совместимость: старый код работает без изменений

