# План имплементации: Интеграция динамического прайс-листа

**Цель:** Настроить Claude бота для работы с динамическим прайс-листом из CSV файла без жесткого прописывания категорий услуг в системном промпте.

## Обзор

Текущая архитектура поддерживает загрузку системного промпта из файла. Нужно расширить её для:
1. Загрузки прайс-листа из CSV файла
2. Динамического извлечения категорий услуг из CSV
3. Комбинирования системного промпта с отформатированным прайс-листом
4. Обновления конфигурации для поддержки пути к прайс-листу с использованием anyway_config best practices

## Этапы реализации

### Этап 1: Обновление конфигурации с использованием anyway_config best practices

#### 1.1 Добавление параметра price_list_path в AppConfig

**Файл:** `config/app_config.rb`

```ruby
require 'anyway_config'

class AppConfig < Anyway::Config
  config_name :kuznik_bot
  env_prefix ''

  # Claude API configuration
  attr_config(
    anthropic_base_url: 'https://api.z.ai/api/anthropic',
    anthropic_auth_token: '',
    anthropic_model: 'glm-4.5-air',
    system_prompt_path: './system-prompt.md',

    # Telegram configuration
    telegram_bot_token: '',

    # Rate limiter configuration
    rate_limit_requests: 10,
    rate_limit_period: 60,

    # Conversation management
    max_history_size: 10,

    # Logging
    log_level: 'info',

    # Bot mode configuration (polling or webhook)
    bot_mode: 'polling',

    # Webhook configuration
    webhook_url: '',
    webhook_port: 3000,
    webhook_host: '0.0.0.0',
    webhook_path: '/telegram/webhook',

    # Price list configuration
    price_list_path: './data/кузник.csv'
  )

  # Обязательные параметры с использованием anyway_config required
  required :anthropic_auth_token, :telegram_bot_token

  # Валидация с использованием on_load callbacks instead of manual checks in initialize
  on_load :validate_system_prompt_file
  on_load :validate_price_list_file
  on_load :validate_bot_mode
  on_load :validate_webhook_requirements
  on_load :validate_numeric_parameters

  private

  def validate_system_prompt_file
    path = system_prompt_path
    raise ArgumentError, "System prompt file not found: #{path}" unless File.exist?(path)
    raise ArgumentError, "System prompt file not readable: #{path}" unless File.readable?(path)
  end

  def validate_price_list_file
    path = price_list_path
    raise ArgumentError, "Price list file not found: #{path}" unless File.exist?(path)
    raise ArgumentError, "Price list file not readable: #{path}" unless File.readable?(path)

    # Дополнительная валидация формата CSV
    unless path.end_with?('.csv')
      raise ArgumentError, "Price list file must be a CSV file: #{path}"
    end
  end

  def validate_bot_mode
    unless %w[polling webhook].include?(bot_mode)
      raise ArgumentError, "BOT_MODE must be 'polling' or 'webhook', got: #{bot_mode}"
    end
  end

  def validate_webhook_requirements
    if bot_mode == 'webhook' && webhook_url.to_s.empty?
      raise ArgumentError, 'WEBHOOK_URL is required when BOT_MODE is webhook'
    end
  end

  def validate_numeric_parameters
    unless rate_limit_requests.is_a?(Integer) && rate_limit_requests > 0
      raise ArgumentError, "RATE_LIMIT_REQUESTS must be a positive integer"
    end

    unless rate_limit_period.is_a?(Integer) && rate_limit_period > 0
      raise ArgumentError, "RATE_LIMIT_PERIOD must be a positive integer"
    end

    unless max_history_size.is_a?(Integer) && max_history_size > 0
      raise ArgumentError, "MAX_HISTORY_SIZE must be a positive integer"
    end
  end
end
```

#### 1.2 Обновление .env.example

**Файл:** `.env.example`

```bash
# Claude API Configuration
ANTHROPIC_AUTH_TOKEN=your_anthropic_api_key
ANTHROPIC_BASE_URL=https://api.z.ai/api/anthropic
ANTHROPIC_MODEL=glm-4.5-air
SYSTEM_PROMPT_PATH=./system-prompt.md

# Telegram Configuration
TELEGRAM_BOT_TOKEN=your_telegram_bot_token

# Rate Limiter Configuration
RATE_LIMIT_REQUESTS=10
RATE_LIMIT_PERIOD=60

# Conversation Management
MAX_HISTORY_SIZE=10

# Logging Configuration
LOG_LEVEL=info

# Bot Mode Configuration
BOT_MODE=polling

# Webhook Configuration (only if BOT_MODE=webhook)
WEBHOOK_URL=https://your-domain.com/webhook
WEBHOOK_PORT=3000
WEBHOOK_HOST=0.0.0.0
WEBHOOK_PATH=/telegram/webhook

# Price List Configuration
PRICE_LIST_PATH=./data/кузник.csv
```

### Этап 2: Создание универсального системного промпта

#### 2.1 Обновление файла системного промпта

**Файл:** `system-prompt.md`

```markdown
# Роль и задача

Ты — консультант автосервиса "Кузник". Твоя задача — помогать клиентам с выбором услуг, составлением сметы и записью на сервис.

## Как работать с прайс-листом

В этом сообщении предоставлен актуальный прайс-лист в формате CSV. Теби нужно:

1. **Найти нужные категории услуг** в прайс-листе (ПОКРАСКА, АНТИКОР, АНТИХРОМ, ДОПОЛНИТЕЛЬНЫЕ УСЛУГИ, ДОПОЛНИТЕЛЬНЫЕ РАБОТЫ)

2. **Определить класс автомобиля** по классификации из прайс-листа:
   - 1 класс: малые и средние авто
   - 2 класс: бизнес класс и кроссоверы
   - 3 класс: представительские, внедорожники, минивены, микроавтобусы

3. **Рассчитать стоимость** на основе цен из соответствующей колонки класса

## Правила консультации

1. **Приветствие:** Приветствуй клиента дружелюбно
2. **Уточнение:** Задавай вопросы об автомобиле для определения класса
3. **Расчет:** Используй ТОЛЬКО цены из предоставленного прайс-листа
4. **Важно:** Все цены указаны ЗА ЭЛЕМЕНТ без учета дополнительных работ
5. **Доп. услуги:** Предлагай дополнительные услуги из соответствующих разделов прайс-листа
6. **Запись:** После согласования стоимости предлагай запись на сервис

## Алгоритм работы:

1. Узнаю, какую услугу хочет клиент
2. Помогаю определить класс автомобиля
3. Нахожу нужную услугу в прайс-листе
4. Рассчитываю стоимость по соответствующей колонке класса
5. Сообщаю, что это базовая цена за элемент
6. Предлагаю дополнительные работы из прайс-листа
7. Рассчитываю итоговую стоимость
8. Предлагаю запись на удобное время

Веди диалог профессионально, но дружелюбно. Используй только информацию из предоставленного прайс-листа.
```

### Этап 3: Модификация ClaudeClient с учетом anyway_config

#### 3.1 Добавление загрузки прайс-листа

**Файл:** `lib/claude_client.rb`

```ruby
require 'httparty'
require 'json'
require 'logger'

class ClaudeClient
  include HTTParty

  MAX_RETRIES = 1

  def initialize(config, logger = Logger.new($stdout))
    @config = config
    @logger = logger

    # anyway_config уже валидировал системный промпт, но загружаем его
    @system_prompt = load_system_prompt

    # Загружаем и форматируем прайс-лист (anyway_config проверил существование файла)
    @price_list = load_and_format_price_list

    @logger.info "ClaudeClient initialized with system prompt and price list"
  end

  def send_message(messages)
    @logger.info "Sending message to Claude API with #{messages.length} messages"

    # Комбинируем системный промпт с отформатированным прайс-листом
    combined_system_prompt = "#{@system_prompt}\n\n---\n\n## ПРАЙС-ЛИСТ\n\n#{@price_list}"

    body = {
      model: @config.anthropic_model,
      max_tokens: 1500,  # Увеличиваем для учета контекста прайс-листа
      system: combined_system_prompt,
      messages: messages
    }

    retries = 0
    begin
      response = self.class.post(
        @config.anthropic_base_url,
        headers: {
          'Authorization' => "Bearer #{@config.anthropic_auth_token}",
          'Content-Type' => 'application/json'
        },
        body: body.to_json
      )

      if response.success?
        parse_response(response)
      else
        handle_error_response(response)
      end
    rescue StandardError => e
      retries += 1
      if retries <= MAX_RETRIES
        @logger.warn "Error sending message to Claude API, retrying (#{retries}/#{MAX_RETRIES}): #{e.message}"
        sleep(1)  # Wait before retrying
        retry
      else
        @logger.error "Failed to send message to Claude API after #{MAX_RETRIES} retries: #{e.message}"
        raise e
      end
    end
  end

  private

  def load_system_prompt
    # anyway_config уже проверил существование файла, но добавляем дополнительную защиту
    path = @config.system_prompt_path
    content = File.read(path, encoding: 'UTF-8')

    if content.strip.empty?
      @logger.error "System prompt file is empty: #{path}"
      raise "System prompt file is empty: #{path}"
    end

    content
  rescue => e
    @logger.error "Failed to load system prompt: #{e.message}"
    raise e
  end

  def load_and_format_price_list
    price_list_path = @config.price_list_path

    # anyway_config уже проверил существование и читаемость файла
    content = File.read(price_list_path, encoding: 'UTF-8')

    if content.strip.empty?
      @logger.error "Price list file is empty: #{price_list_path}"
      return "❌ Прайс-лист пуст. Пожалуйста, обратитесь позже."
    end

    format_price_list_for_claude(content)
  rescue => e
    @logger.error "Failed to load price list: #{e.message}"
    "❌ Прайс-лист временно недоступен. Пожалуйста, обратитесь позже."
  end

  def format_price_list_for_claude(csv_content)
    # Убираем лишние пустые строки и форматируем для лучшего понимания
    lines = csv_content.split("\n").reject(&:empty?)

    formatted = "📋 АКТУАЛЬНЫЙ ПРАЙС-ЛИСТ АВТОСЕРВИСА 'КУЗНИК'\n\n"

    lines.each do |line|
      next if line.strip.empty?

      # Добавляем эмодзи для категорий
      if line.include?('ПОКРАСКА')
        formatted += "🎨 #{line}\n"
      elsif line.include?('АНТИКОР')
        formatted += "🛡️ #{line}\n"
      elsif line.include?('АНТИХРОМ')
        formatted += "⚫ #{line}\n"
      elsif line.include?('ДОПОЛНИТЕЛЬНЫЕ УСЛУГИ')
        formatted += "⭐ #{line}\n"
      elsif line.include?('ДОПОЛНИТЕЛЬНЫЕ РАБОТЫ')
        formatted += "🔧 #{line}\n"
      elsif line.include?('Класс') || line.include?('класс')
        formatted += "📊 #{line}\n"
      else
        formatted += "#{line}\n"
      end
    end

    # Добавляем важное примечание
    formatted += "\n" + "─" * 50 + "\n"
    formatted += "⚠️ ВАЖНОЕ ПРИМЕЧАНИЕ:\n"
    formatted += "• Все цены указаны ЗА ЭЛЕМЕНТ без учета дополнительных работ\n"
    formatted += "• Дополнительные работы оплачиваются отдельно по этому прайс-листу\n"
    formatted += "• Окончательная стоимость определяется после диагностики\n"
    formatted += "─" * 50 + "\n"

    formatted
  end

  def parse_response(response)
    data = JSON.parse(response.body)
    content = data.dig('content', 0, 'text')

    if content.nil?
      @logger.error "Unexpected response format from Claude API: #{data}"
      raise "Unexpected response format from Claude API"
    end

    content
  rescue JSON::ParserError => e
    @logger.error "Failed to parse Claude API response: #{e.message}"
    raise e
  end

  def handle_error_response(response)
    @logger.error "Claude API error (#{response.code}): #{response.body}"
    raise "Claude API error (#{response.code}): #{response.body}"
  end
end
```

### Этап 4: Обновление документации

#### 4.1 Обновление README.md

Добавить информацию о новой функциональности:

```markdown
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
```

### Этап 5: Тестирование

#### 5.1 Unit-тесты для конфигурации

**Файл:** `test/test_app_config_extended.rb`

```ruby
require 'test_helper'

class TestAppConfigExtended < Minitest::Test
  def setup
    # Создаем тестовые файлы
    File.write('./test/fixtures/test_system_prompt.md', 'test prompt')
    File.write('./test/fixtures/test_price_list.csv', 'test,csv,data')
  end

  def teardown
    # Удаляем тестовые файлы
    File.delete('./test/fixtures/test_system_prompt.md') if File.exist?('./test/fixtures/test_system_prompt.md')
    File.delete('./test/fixtures/test_price_list.csv') if File.exist?('./test/fixtures/test_price_list.csv')
  end

  def test_required_parameters_validation
    # Тест валидации обязательных параметров
    assert_raises(AnywayConfig::ValidationError) do
      AppConfig.new(
        anthropic_auth_token: nil,
        telegram_bot_token: 'test_token'
      )
    end
  end

  def test_file_validation
    # Тест валидации файлов
    assert_raises(ArgumentError) do
      AppConfig.new(
        anthropic_auth_token: 'test_token',
        telegram_bot_token: 'test_token',
        system_prompt_path: './nonexistent.md'
      )
    end
  end

  def test_numeric_validation
    # Тест валидации числовых параметров
    assert_raises(ArgumentError) do
      AppConfig.new(
        anthropic_auth_token: 'test_token',
        telegram_bot_token: 'test_token',
        rate_limit_requests: -1
      )
    end
  end

  def test_successful_configuration
    # Т успешной конфигурации
    config = AppConfig.new(
      anthropic_auth_token: 'test_token',
      telegram_bot_token: 'test_token',
      system_prompt_path: './test/fixtures/test_system_prompt.md',
      price_list_path: './test/fixtures/test_price_list.csv'
    )

    assert_equal 'test_token', config.anthropic_auth_token
    assert_equal './test/fixtures/test_price_list.csv', config.price_list_path
  end
end
```

#### 5.2 Unit-тесты для ClaudeClient

**Файл:** `test/test_claude_client_price_list.rb`

```ruby
require 'test_helper'

class TestClaudeClientPriceList < Minitest::Test
  def setup
    # Создаем тестовую конфигурацию и файлы
    File.write('./test/fixtures/test_system_prompt.md', 'test prompt')
    File.write('./test/fixtures/test_price_list.csv', "Прайс лист\nПОКРАСКА\nКапот,1000,2000,3000")

    @config = AppConfig.new(
      anthropic_auth_token: 'test_token',
      telegram_bot_token: 'test_token',
      system_prompt_path: './test/fixtures/test_system_prompt.md',
      price_list_path: './test/fixtures/test_price_list.csv'
    )
    @client = ClaudeClient.new(@config)
  end

  def teardown
    # Удаляем тестовые файлы
    File.delete('./test/fixtures/test_system_prompt.md') if File.exist?('./test/fixtures/test_system_prompt.md')
    File.delete('./test/fixtures/test_price_list.csv') if File.exist?('./test/fixtures/test_price_list.csv')
  end

  def test_load_price_list_success
    price_list = @client.instance_variable_get(:@price_list)
    refute_nil price_list
    assert_includes price_list, 'ПОКРАСКА'
    assert_includes price_list, '📋 АКТУАЛЬНЫЙ ПРАЙС-ЛИСТ'
    assert_includes price_list, '🎨'
  end

  def test_price_list_formatting
    price_list = @client.instance_variable_get(:@price_list)
    assert_includes price_list, '⚠️ ВАЖНОЕ ПРИМЕЧАНИЕ'
    assert_includes price_list, 'Все цены указаны ЗА ЭЛЕМЕНТ'
  end

  def test_empty_price_list_handling
    File.write('./test/fixtures/empty_price_list.csv', '')

    config = AppConfig.new(
      anthropic_auth_token: 'test_token',
      telegram_bot_token: 'test_token',
      system_prompt_path: './test/fixtures/test_system_prompt.md',
      price_list_path: './test/fixtures/empty_price_list.csv'
    )
    client = ClaudeClient.new(config)

    price_list = client.instance_variable_get(:@price_list)
    assert_includes price_list, 'Прайс-лист пуст'

    File.delete('./test/fixtures/empty_price_list.csv')
  end
end
```

### Этап 6: Интеграционное тестирование

#### 6.1 Тестирование полного цикла

1. **Запуск бота с валидной конфигурацией**
   - Убедиться, что приложение запускается без ошибок
   - Проверить загрузку прайс-листа

2. **Тестирование запросов к боту**
   - Отправить запрос о покраске детали
   - Проверить, что бот использует актуальные цены из CSV
   - Убедиться, что бот предлагает дополнительные услуги

3. **Тестирование обработки ошибок**
   - Запустить с невалидным прайс-листом
   - Проверить сообщения об ошибках

## Преимущества подхода с anyway_config

### ✅ **Правильная валидация**
- Использование `required` для обязательных параметров
- Использование `on_load` callbacks для кастомной валидации
- Раннее обнаружение ошибок при запуске

### ✅ **Чистый код**
- Логика валидации отделена от бизнес-логики
- Никаких ручных проверок в `initialize`
- Стандартные ошибки ValidationError с понятными сообщениями

### ✅ **Полная динамичность**
- Все категории услуг берутся из CSV
- Классификация автомобилей из CSV
- Цены всегда актуальные

### ✅ **Масштабируемость**
- Добавили новую категорию в CSV - бот автоматически ее видит
- Изменили цены - бот использует новые
- Расширили классификацию - бот работает с ней

### ✅ **Отказоустойчивость**
- Валидация при запуске приложения
- Понятные сообщения об ошибках
- Graceful handling ошибок загрузки файлов

## Порядок реализации

1. **Шаг 1:** Обновить `config/app_config.rb` с использованием `required` и `on_load`
2. **Шаг 2:** Обновить `.env.example`
3. **Шаг 3:** Создать новый системный промпт в `system-prompt.md`
4. **Шаг 4:** Модифицировать `lib/claude_client.rb`
5. **Шаг 5:** Обновить документацию в `README.md`
6. **Шаг 6:** Написать тесты и проверить функциональность

Ожидаемое время реализации: 3-4 часа с учетом тестирования

## Memory Bank: anyway_config Best Practices

### Использование `required`
```ruby
required :param1, :param2  # Обязательные параметры
required :param3, env: "production"  # Только для production
required :param4, env: %i[production staging]  # Для нескольких окружений
```

### Использование `on_load` callbacks
```ruby
on_load :validate_file_existence
on_load do |value|
  # Кастомная валидация
  raise ArgumentError, "Invalid value" unless condition
end
```

### Преимущества над ручными проверками в `initialize`
- Раннее обнаружение ошибок
- Стандартные типы ошибок
- Чистый код
- Поддержка разных окружений
- Тестируемость валидации