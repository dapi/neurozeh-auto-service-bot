# План имплементации: Обогащенные заявки в административный чат

## Обзор

План детализирует процесс имплементации обогащенного формата заявок в соответствии со спецификацией `specs/SPECIFICATION-enriched-request.md`. План разбит на логические этапы с оценкой сроков и зависимостями.

**Общая оценка сроков: 5-7 дней**

---

## Этап 1: Подготовка и анализ (1 день)

### Задачи:

#### 1.1. Анализ текущего кода и зависимостей
- [ ] **Изучить текущую структуру RequestDetector** (`lib/request_detector.rb`)
- [ ] **Проанализировать взаимодействие с LLMClient** и системным промптом
- [ ] **Проверить формат данных** из прайс-листа (`data/price.csv`)
- [ ] **Изучить текущий алгоритм классификации** автомобилей в системном промпте

**Ожидаемый результат:** Полное понимание текущей архитектуры и точек интеграции

#### 1.2. Подготовка тестовых данных
- [ ] **Создать тестовые сценарии** с разным уровнем информации:
  - Полная информация (марка, модель, услуги)
  - Частичная информация (только услуги)
  - Минимальная информация (только тип заявки)
- [ ] **Подготовить тестовые данные прайс-листа** для разных классов авто
- [ ] **Настроить тестовый admin_chat_id** для отладки

**Ожидаемый результат:** Готовые тестовые данные для валидации функциональности

---

## Этап 2: Расширение RequestDetector (2 дня)

### Задачи:

#### 2.1. Добавление новых параметров в Tool
**Файл:** `lib/request_detector.rb`

```ruby
# Новые параметры
param :car_info, desc: "Информация об автомобиле (марка, модель, класс, пробег)", required: false
param :required_services, desc: "Перечень необходимых работ", required: false
param :cost_calculation, desc: "Расчет стоимости услуг", required: false
param :dialog_context, desc: "Контекст диалога для понимания ситуации", required: false
```

- [ ] **Добавить новые параметры** с описаниями
- [ ] **Обновить валидацию** параметров
- [ ] **Обновить документацию** Tool

#### 2.2. Разборка текущей логики форматирования
- [ ] **Выделить базовое форматирование** в отдельный метод `format_basic_info`
- [ ] **Создать методы** для обогащенных полей:
  - `format_car_info(car_info)`
  - `format_required_services(services)`
  - `format_cost_calculation(cost_data)`
  - `format_dialog_context(context)`
- [ ] **Создать основной метод** `format_enriched_notification`

#### 2.3. Реализация новых методов форматирования

```ruby
def format_car_info(car_info)
  return "" unless car_info

  info = "\n🚗 **Информация об автомобиле:**\n"
  info += "• **Марка и модель:** #{car_info[:make_model]}\n" if car_info[:make_model]
  info += "• **Класс автомобиля:** #{car_info[:class]}\n" if car_info[:class]
  info += "• **Пробег:** #{car_info[:mileage]}\n" if car_info[:mileage]
  info += "\n"
end

def format_required_services(services)
  return "" unless services&.any?

  info = "🔧 **Необходимые работы:**\n"
  services.each_with_index do |service, index|
    info += "#{index + 1}. #{service}\n"
  end
  info += "\n"
end

def format_cost_calculation(cost_data)
  return "" unless cost_data

  info = "💰 **Расчет стоимости:**\n"
  if cost_data[:services]&.any?
    cost_data[:services].each do |service|
      info += "• #{service[:name]}: #{service[:price]}\n"
    end
    info += "• **Итого базовая стоимость:** #{cost_data[:total]}\n"
  end
  info += "• *#{cost_data[:note] || 'Окончательная стоимость определяется после диагностики'}*\n\n"
end
```

- [ ] **Реализовать все методы форматирования**
- [ ] **Добавить обработку пустых данных**
- [ ] **Обеспечить валидный Markdown** формат

#### 2.4. Unit тесты для RequestDetector
**Файл:** `test/test_request_detector_enriched.rb`

```ruby
class TestRequestDetectorEnriched < Minitest::Test
  def test_format_car_info_complete
    car_info = { make_model: "Toyota Camry", class: "2 класс", mileage: "85 000 км" }
    result = @detector.send(:format_car_info, car_info)
    assert_includes result, "Toyota Camry"
    assert_includes result, "2 класс"
    assert_includes result, "85 000 км"
  end

  def test_format_car_info_empty
    result = @detector.send(:format_car_info, nil)
    assert_equal "", result
  end

  # ... другие тесты
end
```

- [ ] **Создать unit тесты** для всех новых методов
- [ ] **Протестировать форматирование** с разными типами данных
- [ ] **Проверить Markdown валидность**

**Ожидаемый результат:** RequestDetector поддерживает обогащенный формат с полной тестовой покрытостью

---

## Этап 3: Сбор информации из диалога (1-2 дня)

### Задачи:

#### 3.1. Создание анализатора диалога
**Новый файл:** `lib/dialog_analyzer.rb`

```ruby
class DialogAnalyzer
  PATTERNS = {
    car_brands: /(toyota|hyundai|kia|bmw|mercedes|lada|renault|daewoo|chevrolet|honda|nissan)/i,
    car_models: /(camry|solaris|rio|logan|aveo|accord|optima|creta|qashqai)/i,
    years: /\b(19|20)\d{2}\b/,
    mileage: /\b\d{2,6}\s*(км|km|thousand)\b/i,
    services: /(диагностика|ремонт|замена|проверка|то|обслуживание)/i
  }

  def extract_car_info(conversation_history)
    {
      make_model: extract_make_model(conversation_history),
      year: extract_year(conversation_history),
      mileage: extract_mileage(conversation_history)
    }
  end

  def extract_services(conversation_history)
    services = []
    conversation_history.each do |message|
      services.concat(extract_services_from_text(message[:content]))
    end
    services.uniq
  end

  private

  def extract_make_model(conversation_history)
    # Логика извлечения марки и модели
  end

  # ... другие приватные методы
end
```

- [ ] **Создать класс DialogAnalyzer** для извлечения информации из диалога
- [ ] **Реализовать паттерны** для поиска марок, моделей, лет, пробега
- [ ] **Добавить извлечение** необходимых услуг из сообщений
- [ ] **Реализовать определение класса** авто на основе марки/модели

#### 3.2. Интеграция с системным промптом
**Файл:** `data/system-prompt.md`

```markdown
## Формирование данных для обогащенной заявки

При использовании RequestDetector собирай следующую информацию из диалога:

### Обязательные данные:
- Перечень необходимых работ (из сообщений пользователя)

### Дополнительные данные для обогащения заявки:
- **Марка и модель авто:** ищи упоминания в диалоге
- **Класс автомобиля:** определяй по марке/модели:
  - 1 класс: Lada, Daewoo, Kia Rio, Hyundai Solaris, Renault Logan, Chevrolet Aveo
  - 2 класс: Toyota Camry, Honda Accord, Kia Optima, Hyundai Creta, Nissan Qashqai
  - 3 класс: BMW 7-series, Mercedes S-Class, Toyota Land Cruiser, Honda CR-V
- **Пробег:** если пользователь упоминал
- **Расчет стоимости:** если возможно по прайс-листу
- **Контекст проблемы:** описание ситуации от пользователя

### Порядок действий при вызове RequestDetector:
1. Проанализируй весь диалог для сбора информации об авто
2. Определи необходимые работы из сообщений пользователя
3. Рассчитай примерную стоимость по прайс-листу (если возможно)
4. Сформируй обогащенную заявку с всей собранной информацией
```

- [ ] **Добавить инструкции** в системный промпт по сбору информации
- [ ] **Обновить правила классификации** автомобилей
- [ ] **Добавить алгоритм работы** с DialogAnalyzer

#### 3.3. Создание калькулятора стоимости
**Новый файл:** `lib/cost_calculator.rb`

```ruby
class CostCalculator
  def initialize(price_list_path)
    @price_list = load_price_list(price_list_path)
  end

  def calculate_cost(services, car_class)
    total = 0
    calculated_services = []

    services.each do |service|
      price = find_price(service, car_class)
      if price
        calculated_services << {
          name: "#{service} (#{car_class_description(car_class)})",
          price: format_price(price)
        }
        total += price
      end
    end

    {
      services: calculated_services,
      total: format_price(total),
      note: "Окончательная стоимость определяется после диагностики"
    }
  end

  private

  def car_class_description(car_class)
    case car_class
    when 1 then "малые и средние авто"
    when 2 then "бизнес-класс и кроссоверы"
    when 3 then "представительские, внедорожники"
    end
  end

  # ... другие методы
end
```

- [ ] **Создать CostCalculator** для расчета стоимости по прайс-листу
- [ ] **Реализовать поиск услуг** в прайс-листе
- [ ] **Добавить форматирование цен** и расчетов
- [ ] **Обработать случаи**, когда услуги не найдены

**Ожидаемый результат:** Система может извлекать информацию из диалога и рассчитывать стоимость

---

## Этап 4: Интеграция компонентов (1 день)

### Задачи:

#### 4.1. Модификация LLMClient для обогащения данных
**Файл:** `lib/llm_client.rb`

```ruby
def send_message(messages, user_info = nil)
  # ... существующий код ...

  # Добавляем обогащенные инструменты если настроен admin_chat_id
  if user_info && @config.admin_chat_id
    request_detector = create_enriched_request_detector(messages, user_info)
    chat.with_tool(request_detector)

    # ... существующий код с callback'ами ...
  end

  # ... остальная логика ...
end

private

def create_enriched_request_detector(messages, user_info)
  # Извлекаем информацию из диалога
  dialog_analyzer = DialogAnalyzer.new
  cost_calculator = CostCalculator.new(@config.price_list_path)

  car_info = dialog_analyzer.extract_car_info(messages)
  required_services = dialog_analyzer.extract_services(messages)

  # Рассчитываем стоимость если возможно
  cost_calculation = nil
  if car_info[:class] && required_services.any?
    cost_calculation = cost_calculator.calculate_cost(required_services, car_info[:class])
  end

  # Создаем обогащенный RequestDetector
  RequestDetector.new(@config, @logger).tap do |detector|
    detector.enrich_with(
      car_info: car_info,
      required_services: required_services,
      cost_calculation: cost_calculation,
      dialog_context: extract_dialog_context(messages)
    )
  end
end
```

- [ ] **Модифицировать метод send_message** для сбора обогащенной информации
- [ ] **Добавить создание DialogAnalyzer** и CostCalculator
- [ ] **Обеспечить передачу** обогащенных данных в RequestDetector
- [ ] **Обновить обработку ошибок** и логирование

#### 4.2. Обновление RequestDetector для поддержки обогащения
**Файл:** `lib/request_detector.rb`

```ruby
class RequestDetector < RubyLLM::Tool
  attr_reader :enriched_data

  def initialize(config, logger = nil)
    @config = config
    @logger = logger || Logger.new(IO::NULL)
    @enriched_data = {}
  end

  def enrich_with(car_info:, required_services:, cost_calculation:, dialog_context:)
    @enriched_data = {
      car_info: car_info,
      required_services: required_services,
      cost_calculation: cost_calculation,
      dialog_context: dialog_context
    }
  end

  def execute(message_text:, user_id:, username: nil, first_name: nil, conversation_context: nil)
    # ... существующий код ...

    result = send_to_admin_chat(
      request_info,
      user_id,
      username,
      first_name,
      admin_chat_id,
      @enriched_data  # Передача обогащенных данных
    )

    # ... остальной код ...
  end

  private

  def format_admin_notification(request_info, user_id, username, first_name, admin_chat_id, enriched_data = {})
    # Базовая информация
    notification = format_basic_info(request_info, user_id, username, first_name)

    # Обогащенная информация
    notification += format_car_info(enriched_data[:car_info])
    notification += format_required_services(enriched_data[:required_services])
    notification += format_cost_calculation(enriched_data[:cost_calculation])
    notification += format_dialog_context(enriched_data[:dialog_context])
    notification += format_action_buttons(user_id)

    notification
  end
end
```

- [ ] **Добавить метод enrich_with** для получения обогащенных данных
- [ ] **Обновить метод execute** для передачи обогащенных данных
- [ ] **Модифицировать format_admin_notification** для использования новых данных
- [ ] **Обеспечить обратную совместимость** со старым форматом

**Ожидаемый результат:** Полностью интегрированная система обогащенных заявок

---

## Этап 5: Тестирование и отладка (1 день)

### Задачи:

#### 5.1. Интеграционные тесты
**Файл:** `test/test_enriched_requests_integration.rb`

```ruby
class TestEnrichedRequestsIntegration < Minitest::Test
  def setup
    @config = AppConfig.new(
      admin_chat_id: 123456789,
      telegram_bot_token: "test_token",
      price_list_path: "test/fixtures/price.csv"
    )
    @llm_client = LLMClient.new(@config)
  end

  def test_full_enriched_request_flow
    messages = [
      { role: "user", content: "Здравствуйте! У меня Toyota Camry 2018. Нужна диагностика подвески." },
      { role: "assistant", content: "Хорошо, я помогу вам с диагностикой." }
    ]

    user_info = { id: 12345, username: "test_user", first_name: "Test" }

    # Тестирование полного цикла
    response = @llm_client.send_message(messages, user_info)
    assert response

    # Проверка обогащенных данных (через моки)
    # ...
  end

  def test_partial_information_request
    # Тест с частичной информацией
  end

  def test_minimal_information_request
    # Тест с минимальной информацией
  end
end
```

- [ ] **Создать интеграционные тесты** для разных сценариев
- [ ] **Протестировать полный цикл** от сообщения до заявки
- [ ] **Проверить обработку ошибок** и граничных случаев
- [ ] **Протестировать форматирование** сообщений

#### 5.2. Ручное тестирование
- [ ] **Настроить тестовый бот** с обогащенными заявками
- [ ] **Протестировать реальные диалоги** с разным уровнем информации
- [ ] **Проверить корректность** расчета стоимости
- [ ] **Валидировать Markdown** форматирование в Telegram

#### 5.3. Отладка и оптимизация
- [ ] **Проанализировать логи** на предмет ошибок
- [ ] **Оптимизировать производительность** DialogAnalyzer и CostCalculator
- [ ] **Улучшить паттерны** для извлечения информации
- [ ] **Настроить детальное логирование** для мониторинга

**Ожидаемый результат:** Надежно работающая система обогащенных заявок

---

## Этап 6: Документация и развертывание (0.5 дня)

### Задачи:

#### 6.1. Обновление документации
- [ ] **Обновить README.md** с описанием новой функциональности
- [ ] **Дополнить ADMIN_CHAT_NOTIFICATIONS.md** примерами обогащенных заявок
- [ ] **Создать guide** по использованию новой системы
- [ ] **Обновить CLAUDE.md** с новыми компонентами

#### 6.2. Подготовка к развертыванию
- [ ] **Обновить переменные окружения** при необходимости
- [ ] **Проверить совместимость** с существующими функциями
- [ ] **Создать backup** текущей версии
- [ ] **Подготовить план отката** в случае проблем

**Ожидаемый результат:** Готовая к развертыванию система с полной документацией

---

## План проверки качества

### Функциональные требования:
- [ ] RequestDetector обогащает заявки информацией из диалога
- [ ] DialogAnalyzer корректно извлекает информацию об авто
- [ ] CostCalculator точно рассчитывает стоимость по прайс-листу
- [ ] Система работает с разным уровнем информации
- [ ] Markdown форматирование корректно отображается в Telegram

### Нефункциональные требования:
- [ ] Производительность не ухудшается significantly
- [ ] Обратная совместимость сохранена
- [ ] Ошибки не приводят к отказу основной функциональности
- [ ] Логирование позволяет отслеживать проблемы

### Тестовое покрытие:
- [ ] Unit тесты покрывают новые методы (минимум 90%)
- [ ] Интеграционные тесты проверяют полный цикл
- [ ] Ручное тестирование подтверждает работоспособность

---

## Риски и митигации

### Риск 1: Низкое качество извлечения информации из диалога
**Митигация:**
- Использование качественных паттернов и регулярных выражений
- Постепенное улучшение на основе реальных данных
- Запасной вариант через уточняющие вопросы

### Риск 2: Некорректный расчет стоимости
**Митигация:**
- Тщательное тестирование с прайс-листом
- Обработка случаев, когда услуги не найдены
- Явное указание на приблизительный характер расчета

### Риск 3: Проблемы с производительностью
**Митигация:**
- Оптимизация паттернов и алгоритмов
- Кэширование результатов анализа диалога
- Мониторинг производительности

### Риск 4: Сложность отладки
**Митигация:**
- Детальное логирование всех этапов
- Разделение компонентов на независимые модули
- Создание debugging mode для разработки

---

## Критерии готовности к продакшен

✅ **Функциональность:**
- Все компоненты работают корректно
- Система обрабатывает разные уровни информации
- Расчеты стоимости точны

✅ **Качество:**
- Тестовое покрытие > 85%
- Нет критических багов
- Производительность в пределах нормы

✅ **Документация:**
- Обновлена вся документация
- Есть примеры использования
- Инструкции по развертыванию

✅ **Мониторинг:**
- Настроено логирование
- Есть метрики работы системы
- План реагирования на инциденты

---

**Общий срок имплементации: 5-7 дней**
**Рекомендуемый подход:** Пошаговая разработка с тестированием каждого этапа
**Приоритет:** Качество и надежность > скорость внедрения