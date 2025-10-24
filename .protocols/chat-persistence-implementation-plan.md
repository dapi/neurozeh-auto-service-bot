# План реализации: Сохранение переписки между рестартами бота

## Этап 1: Подготовка окружения и зависимостей

### 1.1 Обновление Gemfile
```ruby
# Добавить новые зависимости
gem 'sqlite3', '~> 2.0'
gem 'activerecord', '~> 8.1'
gem 'standalone_migrations', '~> 8.0'

# Обновить ruby_llm до последней версии для поддержки ActiveRecord
gem 'ruby_llm', '~> 1.7'
```

### 1.2 Установка зависимостей
```bash
bundle install
```

### 1.3 Создание структуры директорий
```bash
mkdir -p db/migrate
mkdir -p app/models
mkdir -p config
```

### 1.4 Настройка Standalone Migrations
Создать файл `Rakefile`:
```ruby
require 'bundler/gem_tasks'
require 'standalone_migrations'

StandaloneMigrations::Tasks.load_tasks
```

Создать файл `config/database.yml`:
```yaml
development:
  adapter: sqlite3
  database: db/development.sqlite3
  pool: 5
  timeout: 5000

test:
  adapter: sqlite3
  database: db/test.sqlite3
  pool: 5
  timeout: 5000

production:
  adapter: sqlite3
  database: db/production.sqlite3
  pool: 5
  timeout: 5000
```

## Этап 2: Создание миграций базы данных

### 2.1 Первая миграция - таблицы ruby_llm
Создать файл `db/migrate/001_create_ruby_llm_tables.rb`:
```ruby
class CreateRubyLlmTables < ActiveRecord::Migration[7.0]
  def change
    # Таблица для хранения чатов
    create_table :chats do |t|
      t.string :model, null: false
      t.string :provider
      t.string :title
      t.timestamps
    end

    # Таблица для хранения сообщений
    create_table :messages do |t|
      t.references :chat, null: false, foreign_key: true
      t.string :role, null: false
      t.text :content, null: false
      t.string :model_id
      t.integer :input_tokens
      t.integer :output_tokens
      t.string :tool_call_id
      t.json :metadata
      t.timestamps
    end

    add_index :messages, :role
    add_index :messages, :model_id

    # Таблица для tool calls
    create_table :tool_calls do |t|
      t.references :message, null: false, foreign_key: true
      t.string :name, null: false
      t.json :arguments, null: false
      t.string :tool_call_id
      t.timestamps
    end
  end
end
```

### 2.2 Вторая миграция - расширение чатов для Telegram
Создать файл `db/migrate/002_add_telegram_fields_to_chats.rb`:
```ruby
class AddTelegramFieldsToChats < ActiveRecord::Migration[7.0]
  def change
    add_column :chats, :telegram_user_id, :integer
    add_column :chats, :telegram_chat_id, :integer
    add_column :chats, :telegram_username, :string
    add_column :chats, :telegram_first_name, :string
    add_column :chats, :telegram_last_name, :string

    add_index :chats, :telegram_user_id
    add_index :chats, :telegram_chat_id
    add_index :chats, :telegram_username
  end
end
```

### 2.3 Запуск миграций
```bash
rake db:migrate
```

## Этап 3: Создание ActiveRecord моделей

### 3.1 Модель Chat
Создать файл `app/models/chat.rb`:
```ruby
# frozen_string_literal: true

class Chat < ApplicationRecord
  acts_as_chat

  # Telegram ассоциации
  belongs_to :telegram_user,
             class_name: 'TelegramUser',
             optional: true,
             foreign_key: 'telegram_user_id',
             primary_key: 'telegram_id'

  # Валидации
  validates :model, presence: true
  validates :telegram_user_id, uniqueness: { scope: :telegram_chat_id }, allow_nil: true

  # Scopes
  scope :by_telegram_user, ->(user_id) { where(telegram_user_id: user_id) }
  scope :recent, -> { order(updated_at: :desc) }

  # Методы для удобной работы
  def telegram_display_name
    return telegram_user&.display_name if telegram_user

    parts = [telegram_first_name, telegram_last_name].compact
    parts.any? ? parts.join(' ') : "User ##{telegram_user_id}"
  end

  def self.find_or_create_by_telegram_user(user_info)
    user_id = user_info[:id]
    chat_id = user_info[:chat_id] || user_id

    find_by(telegram_user_id: user_id, telegram_chat_id: chat_id) ||
      create!(
        telegram_user_id: user_id,
        telegram_chat_id: chat_id,
        telegram_username: user_info[:username],
        telegram_first_name: user_info[:first_name],
        telegram_last_name: user_info[:last_name],
        model: AppConfig.llm_model,
        provider: AppConfig.llm_provider
      )
  end
end
```

### 3.2 Модель Message
Создать файл `app/models/message.rb`:
```ruby
# frozen_string_literal: true

class Message < ApplicationRecord
  acts_as_message

  # Ассоциации
  belongs_to :chat
  has_many :tool_calls, dependent: :destroy

  # Валидации
  validates :role, presence: true, inclusion: { in: %w[user assistant system tool] }
  validates :content, presence: true

  # Scopes
  scope :by_role, ->(role) { where(role: role) }
  scope :user_messages, -> { by_role('user') }
  scope :assistant_messages, -> { by_role('assistant') }
  scope :recent, -> { order(created_at: :asc) }

  # Методы для удобной работы
  def from_user?
    role == 'user'
  end

  def from_assistant?
    role == 'assistant'
  end

  def has_tool_calls?
    tool_calls.any?
  end

  def truncated_content(length = 100)
    return content if content.length <= length
    content.truncate(length) + '...'
  end
end
```

### 3.3 Модель ToolCall
Создать файл `app/models/tool_call.rb`:
```ruby
# frozen_string_literal: true

class ToolCall < ApplicationRecord
  belongs_to :message

  validates :name, presence: true
  validates :arguments, presence: true

  def arguments_hash
    arguments.is_a?(Hash) ? arguments : JSON.parse(arguments || '{}')
  rescue JSON::ParserError
    {}
  end
end
```

### 3.4 Модель TelegramUser (опционально)
Создать файл `app/models/telegram_user.rb`:
```ruby
# frozen_string_literal: true

class TelegramUser < ApplicationRecord
  self.primary_key = 'telegram_id'

  has_many :chats, foreign_key: 'telegram_user_id', primary_key: 'telegram_id'

  validates :telegram_id, presence: true, uniqueness: true

  def display_name
    return username if username.present?

    parts = [first_name, last_name].compact
    parts.any? ? parts.join(' ') : "User ##{telegram_id}"
  end

  def full_name
    [first_name, last_name].compact.join(' ')
  end
end
```

### 3.5 Миграция для telegram_users
Создать файл `db/migrate/003_create_telegram_users.rb`:
```ruby
class CreateTelegramUsers < ActiveRecord::Migration[7.0]
  def change
    create_table :telegram_users, id: false do |t|
      t.integer :telegram_id, primary_key: true
      t.string :username
      t.string :first_name
      t.string :last_name
      t.boolean :is_bot, default: false
      t.string :language_code
      t.timestamps
    end

    add_index :telegram_users, :username
  end
end
```

## Этап 4: Настройка ActiveRecord в приложении

### 4.1 Создание конфигурации ActiveRecord
Создать файл `config/database.rb`:
```ruby
# frozen_string_literal: true

require 'active_record'
require 'yaml'

module DatabaseConfig
  def self.setup
    environment = ENV['RAILS_ENV'] || 'development'
    db_config = YAML.load_file(File.join(File.dirname(__FILE__), '..', 'db', 'config.yml'))[environment]

    ActiveRecord::Base.establish_connection(db_config)
    ActiveRecord::Base.logger = Logger.new($stdout) if ENV['DEBUG']

    # Загрузка моделей
    Dir[File.join(File.dirname(__FILE__), '..', 'app', 'models', '*.rb')].each { |f| require f }
  end
end
```

### 4.2 Интеграция в bot.rb
Добавить в начало файла `bot.rb`:
```ruby
require_relative 'config/database'

# Инициализация базы данных
DatabaseConfig.setup
```

## Этап 5: Рефакторинг ConversationManager

### 5.1 Новый ConversationManager
Полностью переписать файл `lib/conversation_manager.rb`:
```ruby
# frozen_string_literal: true

require_relative '../app/models/chat'
require_relative '../app/models/message'

class ConversationManager
  def initialize(config = nil)
    @config = config
    @logger = Logger.new($stdout)
  end

  # Получить или создать чат для пользователя
  def get_or_create_chat(user_info)
    @logger.debug "Getting or creating chat for user #{user_info[:id]}"

    chat = Chat.find_or_create_by_telegram_user(user_info)

    # Установить модель если новая запись
    if chat.new_record? || chat.model.blank?
      chat.update!(
        model: @config&.llm_model || 'claude-sonnet-4',
        provider: @config&.llm_provider || 'anthropic'
      )
    end

    chat
  end

  # Получить историю диалога в формате [ {role: 'user', content: '...'} ]
  def get_history(user_id)
    chat = Chat.find_by(telegram_user_id: user_id)
    return [] unless chat

    chat.messages.recent.map do |message|
      {
        role: message.role,
        content: message.content,
        created_at: message.created_at,
        tokens: {
          input: message.input_tokens,
          output: message.output_tokens
        }
      }
    end
  end

  # Добавить сообщение в историю (только для совместимости)
  def add_message(user_id, role, content)
    chat = get_or_create_chat({ id: user_id })

    # RubyLLM автоматически сохраняет сообщения при использовании chat.ask
    # Этот метод оставлен для совместимости с существующим кодом
    @logger.debug "Legacy add_message called for user #{user_id}, role: #{role}"
  end

  # Очистить историю пользователя
  def clear_history(user_id)
    chat = Chat.find_by(telegram_user_id: user_id)
    return false unless chat

    chat.messages.destroy_all
    @logger.info "Cleared history for user #{user_id}"
    true
  end

  # Очистить все истории
  def clear_all
    Message.destroy_all
    Chat.destroy_all
    @logger.info "Cleared all conversation history"
  end

  # Проверить существование диалога
  def user_conversation_exists?(user_id)
    Chat.exists?(telegram_user_id: user_id)
  end

  # Получить статистику
  def get_stats
    {
      total_users: Chat.distinct.count(:telegram_user_id),
      total_chats: Chat.count,
      total_messages: Message.count,
      total_tokens: Message.sum(:input_tokens) + Message.sum(:output_tokens)
    }
  end

  # Получить активных пользователей за последние N дней
  def get_active_users(days = 7)
    Chat.joins(:messages)
        .where('messages.created_at > ?', days.days.ago)
        .distinct
        .count(:telegram_user_id)
  end

  # Найти чаты с ошибками (например, без ответа)
  def find_problematic_chats
    Chat.joins(:messages)
        .where(messages: { role: 'user' })
        .where.not(id: Message.where(role: 'assistant').select(:chat_id))
        .includes(:messages)
  end
end
```

## Этап 6: Обновление LLMClient

### 6.1 Модификация LLMClient
Обновить файл `lib/llm_client.rb`:
```ruby
# frozen_string_literal: true

require 'ruby_llm'
require 'logger'
require_relative 'request_detector'
require_relative 'dialog_analyzer'
require_relative 'cost_calculator'

class LLMClient
  MAX_RETRIES = 1

  def initialize(config, conversation_manager = nil, logger = Logger.new($stdout))
    @config = config
    @logger = logger
    @conversation_manager = conversation_manager || ConversationManager.new(config)
    @logger.info 'LLMClient initialized with system prompt and price list'
  end

  # Новый метод - отправка сообщения с использованием персистентного чата
  def send_message_to_user(user_info, message_content, additional_context = nil)
    @logger.info "Sending message to user #{user_info[:id]}"

    # Получаем или создаем чат для пользователя
    chat = @conversation_manager.get_or_create_chat(user_info)

    # Комбинируем системный промпт
    combined_system_prompt = build_combined_system_prompt

    retries = 0
    begin
      @logger.info "LLMClient model: #{@config.llm_model}, provider: @config.llm_provider}"

      # Устанавливаем системные инструкции
      chat.with_instructions(combined_system_prompt, replace: true)

      # Добавляем дополнительный контекст если есть
      if additional_context
        contextual_content = "#{additional_context}\n\n#{message_content}"
        message_content = contextual_content
      end

      # Добавляем RequestDetector tool если настроен admin_chat_id
      if @config.admin_chat_id
        request_detector = create_enriched_request_detector(chat, user_info)
        chat.with_tool(request_detector)
      end

      # Отправляем сообщение - автоматически сохранится в БД
      response = chat.ask(message_content)

      @logger.info "Response received for user #{user_info[:id]}, tokens: #{response.input_tokens + response.output_tokens}"
      response.content

    rescue RubyLLM::ConfigurationError => e
      @logger.error "RubyLLM configuration error: #{e.message}"
      raise e
    rescue RubyLLM::ModelNotFoundError => e
      @logger.error "Model not found error: #{e.message}"
      raise e
    rescue RubyLLM::Error => e
      @logger.error "RubyLLM API error: #{e.message}"
      raise e
    rescue StandardError => e
      retries += 1
      if retries <= MAX_RETRIES
        @logger.warn "LLM client retry #{retries}/#{MAX_RETRIES}: #{e.message}"
        sleep(1)
        retry
      else
        @logger.error "Failed to send message to RubyLLM after #{MAX_RETRIES} retries: #{e.message}"
        raise e
      end
    end
  end

  # Старый метод для совместимости
  def send_message(messages, user_info = nil)
    return "No user info provided" unless user_info

    # Получаем последнее сообщение
    last_message = messages.is_a?(Array) ? messages.last : messages
    return "No message content" unless last_message && last_message[:content]

    send_message_to_user(user_info, last_message[:content])
  end

  private

  def build_combined_system_prompt
    # Заменяем плейсхолдер [COMPANY_INFO] на содержимое файла с информацией о компании
    prompt_with_company = @config.system_prompt.gsub('[COMPANY_INFO]', @config.company_info)

    # Добавляем прайс-лист
    "#{prompt_with_company}\n\n---\n\n## ПРАЙС-ЛИСТ\n\n#{@config.formatted_price_list}"
  end

  def create_enriched_request_detector(chat, user_info)
    @logger.debug "Creating enriched RequestDetector for user #{user_info[:id]}"

    # Извлекаем информацию из диалога через ruby_llm
    dialog_messages = chat.messages.recent

    # Конвертируем в старый формат для совместимости
    messages_array = dialog_messages.map do |msg|
      { role: msg.role, content: msg.content }
    end

    dialog_analyzer = DialogAnalyzer.new(@logger)
    cost_calculator = CostCalculator.new(@config.price_list_path, @logger)

    car_info = dialog_analyzer.extract_car_info(messages_array)
    required_services = dialog_analyzer.extract_services(messages_array)
    dialog_context = dialog_analyzer.extract_dialog_context(messages_array)

    # Рассчитываем стоимость если возможно
    cost_calculation = nil
    if car_info && car_info[:class] && required_services && required_services.any?
      cost_calculation = cost_calculator.calculate_cost(required_services, car_info[:class])
      @logger.debug "Cost calculation completed: #{cost_calculation.inspect}" if cost_calculation
    end

    # Создаем и обогащаем RequestDetector
    RequestDetector.new(@config, @logger).tap do |detector|
      detector.enrich_with(
        car_info: car_info,
        required_services: required_services,
        cost_calculation: cost_calculation,
        dialog_context: dialog_context
      )
    end
  rescue StandardError => e
    @logger.error "Error creating enriched RequestDetector: #{e.message}"
    # Возвращаем базовый RequestDetector в случае ошибки
    RequestDetector.new(@config, @logger)
  end
end
```

## Этап 7: Обновление TelegramBotHandler

### 7.1 Интеграция с новым LLMClient
Обновить файл `lib/telegram_bot_handler.rb`:
```ruby
# В методе initialize
def initialize(bot_token, config)
  @bot = Telegram::Bot::Client.new(bot_token)
  @config = config
  @rate_limiter = RateLimiter.new(config.rate_limit)
  @conversation_manager = ConversationManager.new(config)
  @llm_client = LLMClient.new(config, @conversation_manager)
  @logger = Logger.new($stdout)
end

# В методе handle_message
def handle_message(message)
  # ... существующий код для проверки rate limit и т.д.

  # Добавляем сообщение в историю
  user_info = extract_user_info(message.from)
  message_content = message.text

  # Отправляем в LLM с персистентным чатом
  response = @llm_client.send_message_to_user(user_info, message_content)

  # Отправляем ответ
  send_message(chat_id, response)
end

private

def extract_user_info(user)
  {
    id: user.id,
    chat_id: user.id, # Можно изменить если есть chat.id
    username: user.username,
    first_name: user.first_name,
    last_name: user.last_name
  }
end
```

## Этап 8: Тестирование

### 8.1 Создание тестовой среды
```bash
# Создать тестовую БД
rake db:create RAILS_ENV=test
rake db:migrate RAILS_ENV=test
```

### 8.2 Написание тестов
Создать файл `test/test_chat_persistence.rb`:
```ruby
# frozen_string_literal: true

require 'test_helper'

class TestChatPersistence < Minitest::Test
  def setup
    # Очищаем тестовую БД перед каждым тестом
    Chat.delete_all
    Message.delete_all
    TelegramUser.delete_all

    @config = OpenStruct.new(
      llm_model: 'claude-sonnet-4',
      llm_provider: 'anthropic'
    )
    @conversation_manager = ConversationManager.new(@config)
  end

  def test_create_chat_for_new_user
    user_info = {
      id: 12345,
      username: 'testuser',
      first_name: 'Test',
      last_name: 'User'
    }

    chat = @conversation_manager.get_or_create_chat(user_info)

    assert chat.persisted?
    assert_equal 12345, chat.telegram_user_id
    assert_equal 'testuser', chat.telegram_username
    assert_equal @config.llm_model, chat.model
  end

  def test_persist_messages_between_restarts
    user_info = { id: 12345, username: 'testuser' }

    # Создаем чат и добавляем сообщение
    chat = @conversation_manager.get_or_create_chat(user_info)
    chat.with_instructions("You are a helpful assistant")

    # Симуляция отправки сообщения (в реальном коде это будет через LLMClient)
    response = chat.ask("Hello, how are you?")

    assert response.content.present?
    assert_equal 2, chat.messages.count # user + assistant

    # Симуляция рестарта - создаем новый ConversationManager
    new_manager = ConversationManager.new(@config)
    history = new_manager.get_history(12345)

    assert_equal 2, history.length
    assert_equal 'user', history.first[:role]
    assert_equal 'Hello, how are you?', history.first[:content]
    assert_equal 'assistant', history.last[:role]
    assert response.content, history.last[:content]
  end

  def test_clear_history
    user_info = { id: 12345 }
    chat = @conversation_manager.get_or_create_chat(user_info)
    chat.ask("Test message")

    assert_equal 2, chat.messages.count

    result = @conversation_manager.clear_history(12345)
    assert result
    assert_equal 0, chat.reload.messages.count
  end

  def test_get_stats
    user1_info = { id: 12345 }
    user2_info = { id: 67890 }

    @conversation_manager.get_or_create_chat(user1_info)
    @conversation_manager.get_or_create_chat(user2_info)

    stats = @conversation_manager.get_stats

    assert_equal 2, stats[:total_users]
    assert_equal 2, stats[:total_chats]
    assert_equal 0, stats[:total_messages] # Нет сообщений еще
  end
end
```

### 8.3 Интеграционные тесты
Создать файл `test/test_persistence_integration.rb`:
```ruby
# frozen_string_literal: true

require 'test_helper'

class TestPersistenceIntegration < Minitest::Test
  def setup
    DatabaseConfig.setup
    Chat.delete_all
    Message.delete_all
  end

  def test_full_conversation_flow
    # Симуляция полного цикла разговора
    config = load_test_config
    manager = ConversationManager.new(config)
    llm_client = LLMClient.new(config, manager)

    user_info = {
      id: 12345,
      username: 'testuser',
      first_name: 'Test',
      last_name: 'User'
    }

    # Первое сообщение
    response1 = llm_client.send_message_to_user(user_info, "Привет! Как у вас дела?")
    assert response1.present?

    # Проверяем сохранение
    chat = Chat.find_by(telegram_user_id: 12345)
    assert chat
    assert_equal 2, chat.messages.count

    # Второе сообщение в том же чате
    response2 = llm_client.send_message_to_user(user_info, "Что вы можете посоветовать по ремонту?")
    assert response2.present?

    # Проверяем историю
    history = manager.get_history(12345)
    assert_equal 4, history.length # 2 user + 2 assistant messages

    # Симуляция рестарта бота
    new_manager = ConversationManager.new(config)
    new_history = new_manager.get_history(12345)

    assert_equal history.length, new_history.length
    assert_equal history.first[:content], new_history.first[:content]
  end

  private

  def load_test_config
    OpenStruct.new(
      llm_model: 'claude-sonnet-4',
      llm_provider: 'anthropic',
      system_prompt: 'You are a helpful assistant',
      company_info: 'Test company',
      price_list_path: 'test/fixtures/price.csv'
    )
  end
end
```

### 8.4 Запуск тестов
```bash
# Запустить все тесты
rake test

# Запустить только тесты персистентности
ruby -Ilib:test test/test_chat_persistence.rb
ruby -Ilib:test test/test_persistence_integration.rb
```

## Этап 9: Развертывание и мониторинг

### 9.1 Создание директории для БД
```bash
mkdir -p db
```

### 9.2 Добавление в .gitignore
```
# Добавить в .gitignore
db/*.sqlite3
db/*.sqlite3-*
```

### 9.3 Скрипт для инициализации БД при деплое
Создать файл `scripts/setup_database.sh`:
```bash
#!/bin/bash
set -e

echo "Setting up database..."

# Создаем директорию если нет
mkdir -p db

# Запускаем миграции
rake db:migrate

echo "Database setup completed!"
```

### 9.4 Мониторинг состояния БД
Добавить в `bot.rb` метод для проверки состояния:
```ruby
def check_database_health
  begin
    Chat.count
    Message.count
    true
  rescue => e
    @logger.error "Database health check failed: #{e.message}"
    false
  end
end
```

## Этап 10: Оптимизация и дополнительный функционал

### 10.1 Очистка старых диалогов
Добавить в ConversationManager:
```ruby
def cleanup_old_messages(days_to_keep = 30)
  cutoff_date = days_to_keep.days.ago

  old_messages = Message.where('created_at < ?', cutoff_date)
  count = old_messages.count

  old_messages.destroy_all

  # Удаляем пустые чаты
  Chat.where.missing(:messages).destroy_all

  @logger.info "Cleaned up #{count} old messages older than #{days_to_keep} days"
  count
end
```

### 10.2 Экспорт/импорт данных
```ruby
def export_user_data(user_id)
  chat = Chat.find_by(telegram_user_id: user_id)
  return nil unless chat

  {
    user: {
      id: chat.telegram_user_id,
      username: chat.telegram_username,
      first_name: chat.telegram_first_name,
      last_name: chat.telegram_last_name
    },
    messages: chat.messages.recent.map do |msg|
      {
        role: msg.role,
        content: msg.content,
        created_at: msg.created_at,
        tokens: {
          input: msg.input_tokens,
          output: msg.output_tokens
        }
      }
    end
  }
end
```

### 10.3 Аналитика использования
```ruby
def get_usage_analytics(days = 7)
  start_date = days.days.ago

  {
    total_users: Chat.joins(:messages)
                     .where('messages.created_at > ?', start_date)
                     .distinct
                     .count(:telegram_user_id),
    total_messages: Message.where('created_at > ?', start_date).count,
    total_tokens: Message.where('created_at > ?', start_date)
                        .sum(:input_tokens + :output_tokens),
    average_messages_per_user: Message.where('created_at > ?', start_date)
                                     .group(:chat_id)
                                     .average(:id)&.values&.sum&.to_f /
                                     Chat.joins(:messages)
                                         .where('messages.created_at > ?', start_date)
                                         .distinct
                                         .count || 0
  }
end
```

## Финальные проверки

1. **Проверить работу с существующими пользователями** - убедиться, что переход на новую систему не прерывает активные диалоги
2. **Тестировать производительность** - убедиться, что запросы к БД не замедляют работу бота
3. **Проверить резервное копирование** - настроить бэкапы БД
4. **Валидировать данные** - убедиться, что все необходимые поля сохраняются корректно
5. **Тестировать восстановление после сбоя** - проверить, что бот корректно восстанавливает состояние после перезапуска

Этот план обеспечивает поэтапную миграцию на персистентное хранение диалогов с минимальным влиянием на существующий функционал и возможностью откатиться на текущую реализацию в случае проблем.