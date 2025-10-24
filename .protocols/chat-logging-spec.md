# Спецификация: Логирование добавления бота в чаты

## Обзор

Необходимо расширить функциональность Telegram-бота для логирования событий, когда бота добавляют в чаты (группы, супергруппы, каналы). Система должна детально логировать информацию о чате и его участниках.

## Требования

### 1. События для отслеживания

- `new_chat_members` - добавление бота в чат
- `group_chat_created` - создание группового чата с ботом
- `supergroup_chat_created` - создание супергруппы с ботом
- `channel_chat_created` - создание канала с ботом

### 2. Логируемая информация

#### Основная информация:
- **ID чата** (`chat.id`)
- **Тип чата** (`chat.type`) - private, group, supergroup, channel
- **Название чата** (`chat.title`) - для групповых чатов
- **Имя пользователя** (`chat.username`) - если есть
- **Дата добавления** (`date`)

#### Информация о добавившем:
- **ID пользователя** (`from.id`)
- **Имя пользователя** (`from.first_name`, `from.last_name`)
- **Username** (`from.username`)
- **Язык** (`from.language_code`)

#### Дополнительная информация:
- **Список всех участников** (если доступно)
- **Права бота** (`can_post_messages`, `can_edit_messages`, etc.)
- **Количество участников** (для супергрупп)

### 3. Формат логирования

#### Успешное добавление:
```
[INFO] Bot added to chat | Chat ID: -1001234567890 | Type: supergroup | Title: "Автосервис" | Added by: user123 (Иван Петров) | Language: ru
```

#### Создание чата:
```
[INFO] New chat created with bot | Chat ID: -123456789 | Type: group | Title: "Новый чат" | Creator: user456 (Мария Иванова)
```

#### Детальная информация:
```json
{
  "event": "bot_added_to_chat",
  "timestamp": "2024-01-01T12:00:00Z",
  "chat": {
    "id": -1001234567890,
    "type": "supergroup",
    "title": "Автосервис",
    "username": "autoservice_chat",
    "description": "Чат по вопросам автосервиса"
  },
  "added_by": {
    "id": 123456789,
    "first_name": "Иван",
    "last_name": "Петров",
    "username": "ivan_petrov",
    "language_code": "ru"
  },
  "bot_permissions": {
    "can_send_messages": true,
    "can_send_media_messages": true,
    "can_edit_messages": false
  }
}
```

### 4. Уровни логирования

- **INFO** - успешное добавление в чат
- **WARN** - добавление с ограниченными правами
- **ERROR** - ошибка при получении информации о чате

### 5. Интеграция с существующим кодом

#### Модификация `TelegramBotHandler`:

1. **Расширить метод `process_message`:**
   ```ruby
   def process_message(message, bot)
     # Обработка новых участников
     if message.new_chat_members
       handle_new_chat_members(message, bot)
       return
     end

     # Существующая логика обработки сообщений
     # ...
   end
   ```

2. **Добавить новый метод `handle_new_chat_members`:**
   ```ruby
   private

   def handle_new_chat_members(message, bot)
     chat = message.chat
     added_by = message.from

     # Проверка, добавлен ли бот
     bot_added = message.new_chat_members.any? { |member| member.is_bot }
     return unless bot_added

     # Логирование информации о чате
     log_chat_info(chat, added_by)

     # Отправка приветственного сообщения
     send_chat_welcome_message(chat.id, bot)
   end
   ```

3. **Добавить метод логирования:**
   ```ruby
   def log_chat_info(chat, added_by)
     chat_info = format_chat_info(chat, added_by)
     @logger.info "Bot added to chat | #{chat_info}"

     # Детальная информация в JSON формате
     detailed_info = build_detailed_chat_info(chat, added_by)
     @logger.debug "Detailed chat info: #{detailed_info.to_json}"
   end
   ```


### 6. Тестирование

#### Unit тесты:
- Тестирование обработки `new_chat_members`
- Тестирование форматирования логов
- Тестирование различных типов чатов
- Тестирование прав доступа

#### Интеграционные тесты:
- Добавление бота в реальный чат
- Проверка корректности логирования
- Проверка обработки ошибок

### 7. Обработка ошибок

- **API ошибки** при получении информации о чате
- **Отсутствие прав** на получение информации об участниках
- **Некорректные данные** в сообщении

### 8. Производительность

- Минимальная задержка при обработке событий
- Кэширование информации о чатах (опционально)
- Асинхронная запись детальных логов

### 9. Безопасность

- Проверка прав доступа перед получением информации
- Фильтрация конфиденциальных данных
- Валидация входных данных

## Реализация

### Приоритет: Высокий
### Временные затраты: ~4-6 часов
### Зависимости:
- Модификация `TelegramBotHandler`
- Дополнение тестового набора