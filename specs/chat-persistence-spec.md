# Спецификация: Сохранение переписки между рестартами бота

## Обзор

Необходимо реализовать персистентность переписки с пользователями между рестартами бота с использованием возможностей gem ruby_llm, который предоставляет встроенную поддержку сохранения истории диалогов через ActiveRecord.

## Текущая архитектура

### ConversationManager
- Хранит историю в памяти (@conversations = {})
- Использует Mutex для thread-safety
- Ограничивает историю N сообщениями (max_history)
- Потеря данных при рестарте приложения

### LLMClient
- Создает новый чат RubyLLM для каждого запроса
- Передает всю историю диалога сообщениями
- Использует RequestDetector для обогащения запросов

## Предлагаемое решение

### 1. Миграция на RubyLLM ActiveRecord модели

**Преимущества:**
- Встроенная поддержка персистентности в ruby_llm
- Автоматическое сохранение всех сообщений (user, assistant, system, tool_call)
- Поддержка токенов, метаданных, файлов
- Минимальные изменения в коде
- Надежное хранение данных

**Реализация:**
```ruby
# Создать модели ActiveRecord (как в Rails)
class Chat < ApplicationRecord
  acts_as_chat
  # telegram_user_id, created_at, updated_at
end

class Message < ApplicationRecord
  acts_as_message
  # content, role, model_id, input_tokens, output_tokens
end
```

### 2. Адаптация ConversationManager

**Новый ConversationManager:**
```ruby
class ConversationManager
  def initialize(config)
    @config = config
  end

  def get_or_create_chat(user_id)
    # Найти или создать чат для пользователя
    Chat.where(telegram_user_id: user_id).first_or_create!(
      model: @config.llm_model,
      provider: @config.llm_provider
    )
  end

  def get_history(user_id)
    chat = get_or_create_chat(user_id)
    chat.messages.order(:created_at).map do |msg|
      { role: msg.role, content: msg.content }
    end
  end

  # Остальные методы адаптировать под ActiveRecord
end
```

### 3. Модификация LLMClient

**Изменения в LLMClient:**
- Использовать существующий Chat вместо создания нового
- Автоматическая загрузка истории из БД
- Сохранение всех новых сообщений

```ruby
def send_message(user_id, messages, user_info = nil)
  chat = @conversation_manager.get_or_create_chat(user_id)

  # Установить системные инструкции если нужно
  chat.with_instructions(combined_system_prompt, replace: true)

  # Добавить инструменты
  chat.with_tool(request_detector) if user_info && @config.admin_chat_id

  # Отправить сообщение - автоматически сохранится в БД
  response = chat.ask(messages.last[:content])
  response.content
end
```

## Технические требования

### 1. База данных
- SQLite для простоты развертывания
- ActiveRecord для работы с БД
- Миграции для создания таблиц

### 2. Новые зависимости
```ruby
# Добавить в Gemfile
gem 'sqlite3', '~> 2.0'
gem 'activerecord', '~> 8.1'
gem 'standalone_migrations', '~> 8.0'
```

### 3. Структура БД
```sql
-- chats
- id: primary key
- telegram_user_id: integer (indexed)
- model: string
- provider: string
- created_at: datetime
- updated_at: datetime

-- messages
- id: primary key
- chat_id: foreign key
- content: text
- role: string (user/assistant/system/tool)
- model_id: string
- input_tokens: integer
- output_tokens: integer
- created_at: datetime
- updated_at: datetime

-- tool_calls (опционально)
- id: primary key
- message_id: foreign key
- name: string
- arguments: json
- created_at: datetime
```

## Преимущества подхода

1. **Надежность:** Данные сохраняются в БД между рестартами
2. **Простота:** Используются встроенные возможности ruby_llm
3. **Масштабируемость:** Легко расширять функциональность
4. **Отладка:** Полная история всех диалогов
5. **Аналитика:** Возможность анализировать токены, модели, etc.
6. **Совместимость:** Минимальные изменения в существующем коде