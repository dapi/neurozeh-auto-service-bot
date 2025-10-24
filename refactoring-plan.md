# План рефакторинга: Перенос загрузки текстовых данных в AppConfig

## Текущая ситуация

**RubyLLMClient** (`lib/ruby_llm_client.rb:13-21`):
- Загружает системный промпт (`@system_prompt`)
- Загружает информацию о компании (`@company_info`)
- Загружает и форматирует прайс-лист (`@price_list`)
- Комбинирует их в методе `build_combined_system_prompt`

**TelegramBotHandler**:
- Загружает welcome message через `read_welcome_message`

**AppConfig**:
- Хранит только пути к файлам
- Валидирует существование файлов, но не загружает их содержимое

## Проблемы текущего подхода

1. **Дублирование логики загрузки** - каждый класс сам читает файлы
2. **Нарушение принципа единой ответственности** - RubyLLMClient занимается и AI, и загрузкой файлов
3. **Сложность тестирования** - трудно мокать загрузку файлов
4. **Отсутствие кэширования** - файлы читаются при каждом создании экземпляра

## План рефакторинга

### Шаг 1: Расширение AppConfig

#### 1.1. Добавить свойства для хранения содержимого файлов
```ruby
# Добавить в config/app_config.rb
attr_config(
  # Существующие пути
  system_prompt_path: './data/system-prompt.md',
  welcome_message_path: './data/welcome-message.md',
  price_list_path: './data/price.csv',
  company_info_path: './data/company-info.md',

  # Новые свойства для хранения содержимого
  system_prompt: nil,
  welcome_message: nil,
  price_list: nil,
  company_info: nil,
  formatted_price_list: nil
)
```

#### 1.2. Добавить методы для загрузки содержимого
```ruby
# Добавить в AppConfig приватные методы
private

def load_system_prompt
  load_text_file(system_prompt_path, "System prompt")
end

def load_company_info
  load_text_file(company_info_path, "Company info")
end

def load_welcome_message
  load_text_file(welcome_message_path, "Welcome message")
end

def load_price_list
  load_text_file(price_list_path, "Price list")
end

def load_text_file(path, description)
  raise ArgumentError, "#{description} file not found: #{path}" unless File.exist?(path)
  content = File.read(path, encoding: 'UTF-8')
  raise ArgumentError, "#{description} file is empty: #{path}" if content.strip.empty?
  content
end

def format_price_list(content)
  # Переместить метод format_price_list_for_claude из RubyLLMClient
  # с небольшими адаптациями
end
```

#### 1.3. Добавить callbacks для загрузки
```ruby
# Добавить в on_load
on_load :load_text_content

private

def load_text_content
  self.system_prompt = load_system_prompt
  self.company_info = load_company_info
  self.welcome_message = load_welcome_message
  raw_price_list = load_price_list
  self.price_list = raw_price_list
  self.formatted_price_list = format_price_list(raw_price_list)
end
```

### Шаг 2: Упрощение RubyLLMClient

#### 2.1. Удалить методы загрузки
- Удалить `load_system_prompt`
- Удалить `load_company_info`
- Удалить `load_and_format_price_list`
- Удалить `format_price_list_for_claude`

#### 2.2. Упростить инициализатор
```ruby
def initialize(config, logger = Logger.new($stdout))
  @config = config
  @logger = logger
  @logger.info 'RubyLLMClient initialized with system prompt and price list'
end
```

#### 2.3. Использовать данные из AppConfig
```ruby
def build_combined_system_prompt
  prompt_with_company = @config.system_prompt.gsub('[COMPANY_INFO]', @config.company_info)
  "#{prompt_with_company}\n\n---\n\n## ПРАЙС-ЛИСТ\n\n#{@config.formatted_price_list}"
end
```

### Шаг 3: Упрощение TelegramBotHandler

#### 3.1. Удалить метод `read_welcome_message`

#### 3.2. Использовать данные из AppConfig
```ruby
# Заменить вызовы read_welcome_message на @config.welcome_message
```

### Шаг 4: Обновление валидации

#### 4.1. Усилить валидацию содержимого
```ruby
def validate_system_prompt_file
  content = load_system_prompt
  validate_system_prompt_content(content)
end

def validate_system_prompt_content(content)
  # Проверить наличие плейсхолдера [COMPANY_INFO]
  unless content.include?('[COMPANY_INFO]')
    @logger.warn "System prompt doesn't contain [COMPANY_INFO] placeholder"
  end
end
```

### Шаг 5: Преимущества рефакторинга

#### 5.1. Централизация управления данными
- Все текстовые данные загружаются в одном месте
- Единая точка валидации

#### 5.2. Улучшение тестируемости
- Легко подменять данные в тестах
- Изоляция файловой системы от бизнес-логики

#### 5.3. Производительность
- Однократная загрузка при старте
- Кэширование в памяти

#### 5.4. Соблюдение SOLID принципов
- **Single Responsibility**: Каждый класс занимается своей задачей
- **Dependency Inversion**: RubyLLMClient зависит от абстракции (AppConfig), а не от файловой системы

### Шаг 6: Обратная совместимость

#### 6.1. Сохранить свойства путей для возможного использования в логировании или отладке

#### 6.2. Добавить методы для перезагрузки (опционально)
```ruby
def reload_text_content!
  load_text_content
end
```

## Итог

Этот рефакторинг позволит:
- Упростить RubyLLMClient и TelegramBotHandler
- Централизовать управление текстовыми данными
- Улучшить тестируемость и поддерживаемость кода
- Соблюсти принципы SOLID

## Затрагиваемые файлы

- `config/app_config.rb` - расширение функциональности
- `lib/ruby_llm_client.rb` - упрощение и удаление логики загрузки
- `lib/telegram_bot_handler.rb` - использование данных из конфигурации