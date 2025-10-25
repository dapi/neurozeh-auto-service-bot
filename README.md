# Авто-Сервис Бот (auto-service-bot) - Telegram Bot AI-ассистент для Записи на Авто-Услуги

Telegram бот для записи на услуги автосервиса.

## Описание проекта

Бот использует LLM для обработки запросов пользователей и ведения диалогов о услугах автосервиса.
Бот отслеживает истории диалогов каждого пользователя и имеет защиту от спама через Rate Limiter.

## 🚀 Quick Start

**Хотите быстро начать?** Выберите ваш путь:

- 🎯 **[Я новичок](#-Запуск-через-docker-Рекомендуется-для-продакшена)** - Docker Compose (просто и надежно)
- 🛠️ **[Я разработчик](#️-Упрощенная-разработка-с-dip-Рекомендуется)** - Dip (максимальная продуктивность)
- ⚡ **[Я хочу локально](#-Запуск-без-docker-классическая-разработка)** - Без Docker (быстрый старт)

## 🚀 Способы запуска бота

| Способ | Для кого | Преимущества | Недостатки |
|--------|----------|---------------|------------|
| **Docker + Dip** | Разработчики | 💪 Максимальная продуктивность, 🔧 Изолированное окружение, 🔄 Быстрый workflow | 🐳 Требуется Docker |
| **Docker Compose** | Продакшен, DevOps | 🚀 Готовый к продакшену, 🔒 Безопасность, 📦 Простота развертывания | 🐢 Медленнее для разработки |
| **Локальная разработка** | Новички, быстрый старт | ⚡ Быстрый старт, 🎓 Легко понять, 💻 Минимум зависимостей | ⚠️ Проблемы с зависимостями, 🔄 Сложный setup |

**Рекомендация:** Используйте **Dip** для разработки, **Docker Compose** для продакшена.

---

## 🚀 Запуск через Docker (Рекомендуется для продакшена)

### Быстрый старт с Docker Compose

1. **Клонировать репозиторий:**
   ```bash
   git clone https://github.com/yourusername/auto-service-bot.git
   cd auto-service-bot
   ```

2. **Создать файл конфигурации:**
   ```bash
   cp .env.example .env
   ```

3. **Отредактировать `.env` файл:**
   ```bash
   nano .env
   ```

   Обязательные параметры:
   ```
   TELEGRAM_BOT_TOKEN=your_telegram_bot_token
   ADMIN_CHAT_ID=123456789  # ID административного чата для уведомлений о заявках
   ```

4. **Настроить базу данных:**
   ```bash
   docker-compose run --rm auto-service-bot rake db:create
   docker-compose run --rm auto-service-bot rake db:migrate
   docker-compose run --rm auto-service-bot rake ruby_llm:load_models
   ```

5. **Запустить бота:**
   ```bash
   docker-compose up -d
   ```

6. **Проверить статус:**
   ```bash
   docker-compose logs -f auto-service-bot
   ```

### Подробная инструкция по запуску

#### Для новичков (пошаговая инструкция)

**Шаг 1: Установка Docker**

**Ubuntu/Debian:**
```bash
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER
# Перезайдите в систему
```

**MacOS:**
- Скачайте Docker Desktop с [docker.com](https://www.docker.com/products/docker-desktop)

**Windows:**
- Скачайте Docker Desktop с [docker.com](https://www.docker.com/products/docker-desktop)

**Шаг 2: Установка Docker Compose (если не установлен)**

```bash
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

**Шаг 3: Получение токенов**

1. **Telegram Bot Token:**
   - Найдите [@BotFather](https://t.me/botfather) в Telegram
   - Отправьте команду `/newbot`
   - Следуйте инструкциям для создания бота
   - Скопируйте полученный токен

2. **Anthropic API Key:**
   - Зарегистрируйтесь на [platform.anthropic.com](https://console.anthropic.com)
   - Перейдите в API Keys
   - Создайте новый API ключ
   - Скопируйте ключ

**Шаг 4: Настройка и запуск**

```bash
# Клонируем репозиторий
git clone https://github.com/yourusername/auto-service-bot.git
cd auto-service-bot

# Создаем конфигурационный файл
cp .env.example .env

# Редактируем конфигурацию
nano .env
```

**Шаг 5: Запуск бота**

```bash
# Запуск в фоновом режиме
docker-compose up -d

# Просмотр логов
docker-compose logs -f auto-service-bot

# Остановка бота
docker-compose down
```

#### Продвинутые опции

**Запуск с webhook режимом:**

1. Измените `.env` файл:
   ```
   BOT_MODE=webhook
   WEBHOOK_URL=https://your-domain.com
   WEBHOOK_PORT=3000
   WEBHOOK_HOST=0.0.0.0
   ```

2. Настройте обратный прокси (Nginx example):
   ```nginx
   server {
       listen 80;
       server_name your-domain.com;

       location / {
           proxy_pass http://localhost:3000;
           proxy_set_header Host $host;
           proxy_set_header X-Real-IP $remote_addr;
       }
   }
   ```

**Мониторинг здоровья:**

```bash
# Проверка статуса контейнера
docker-compose ps

# Проверка здоровья
docker-compose exec auto-service-bot pgrep -f "ruby bot.rb"

# Просмотр использования ресурсов
docker stats auto-service-bot
```

**Обновление до новой версии:**

```bash
# Скачиваем последнюю версию
docker-compose pull

# Перезапускаем с новым образом
docker-compose up -d

# Удаляем старый образ
docker image prune -f
```

### Сборка собственного образа

Если вы хотите собрать образ локально:

```bash
# Сборка образа
docker build -t auto-service-bot .

# Запуск
docker run -d \
  --name auto-service-bot \
  --env-file .env \
  auto-service-bot
```

### Автоматические обновления

Для автоматического обновления образа при изменениях в репозитории используется GitHub Actions. При каждом push в основную ветку:

1. Запускаются тесты
2. Собирается Docker образ
3. Образ публикуется в GitHub Container Registry (GHCR)
4. Создается SBOM (Software Bill of Materials)

Для обновления:

```bash
docker-compose pull && docker-compose up -d
```

### Команды для работы с Docker

| Команда | Описание |
|---------|----------|
| `docker-compose up -d` | Запустить в фоновом режиме |
| `docker-compose down` | Остановить и удалить контейнеры |
| `docker-compose logs -f` | Смотреть логи в реальном времени |
| `docker-compose restart` | Перезапустить контейнер |
| `docker-compose exec auto-service-bot bash` | Войти в контейнер |
| `docker stats auto-service-bot` | Мониторинг ресурсов |

## 🛠️ Упрощенная разработка с Dip (Рекомендуется)

**Dip** - это CLI инструмент, который делает работу с Docker контейнерами такой же удобной, как локальная разработка.

### Установка Dip

```bash
# Глобальная установка
gem install dip

# Или через Bundler (рекомендуется)
bundle add dip --group development
```

### Быстрый старт с Dip

1. **Установите Dip:**
   ```bash
   gem install dip
   ```

2. **Настройте окружение:**
   ```bash
   dip setup
   ```

3. **Запустите бота:**
   ```bash
   dip up
   dip bot
   ```

### Основные команды Dip

| Команда | Описание | Аналог Docker |
|---------|----------|---------------|
| `dip bash` | Открыть shell в контейнере | `docker-compose exec auto-service-bot bash` |
| `dip bot` | Запустить бота | `docker-compose up auto-service-bot` |
| `dip test` | Запустить тесты | `docker-compose exec auto-service-bot bundle exec rake test` |
| `dip rubocop` | Проверить код стилем | `docker-compose exec auto-service-bot bundle exec rubocop` |
| `dip logs` | Смотреть логи бота | `docker-compose logs -f auto-service-bot` |
| `dip restart` | Перезапустить бота | `docker-compose restart auto-service-bot` |
| `dip down` | Остановить все сервисы | `docker-compose down` |

### Продвинутые возможности Dip

#### Shell интеграция (супер-удобно!)

Включите shell интеграцию для выполнения команд без префикса `dip`:

```bash
# Добавьте в ~/.zshrc или ~/.bashrc
echo 'eval "$(dip console)"' >> ~/.zshrc
source ~/.zshrc
```

Теперь можно выполнять команды напрямую:
```bash
# Вместо dip bundle exec rake test
bundle exec rake test

# Вместо dip bash
bash

# Вместо dip logs
logs
```

#### Разработка в реальном времени

```bash
# Запустить контейнер и зайти в shell
dip up
dip bash

# Внутри контейнера:
# - Установить зависимости
bundle install

# - Настроить базу данных
rake db:create
rake db:migrate
rake ruby_llm:load_models

# - Запустить тесты
rake test

# - Запустить бота в режиме разработки
ruby bot.rb
```

#### Команды для кода

```bash
# Проверить стиль кода
dip rubocop

# Автоисправление стиля
dip rubocop-autocorrect

# Запустить все тесты
dip test

# Запустить конкретный тест
dip minitest test/test_rate_limiter.rb
```

#### Управление окружением

```bash
# Первоначальная настройка
dip setup

# Проверить состояние контейнеров
dip health

# Очистить Docker ресурсы
dip clean

# Перезапустить с пересборкой
dip down && dip up
```

### Конфигурация Dip

Файл `dip.yml` содержит все команды и настройки:

- **Shell команды**: `bash`, `sh`, `console`
- **Ruby команды**: `bundle`, `ruby`, `rake`
- **Тестирование**: `test`, `minitest`, `rspec`
- **Качество кода**: `rubocop`, `rubocop-autocorrect`
- **Bot команды**: `bot`, `bot-console`
- **Docker shortcuts**: `up`, `down`, `restart`, `logs`

### Пример рабочего процесса с Dip

```bash
# 1. Клонирование и настройка
git clone https://github.com/yourusername/auto-service-bot.git
cd auto-service-bot
dip setup

# 2. Запуск окружения
dip up

# 3. Разработка
dip bash
# Внутри контейнера:
# - Редактировать код
# - Запускать тесты: rake test
# - Проверять стиль: rubocop
# - Запускать бота: ruby bot.rb

# 4. Перед коммитом
dip rubocop
dip test

# 5. Очистка
dip down
```

**Dip делает разработку с Docker такой же удобной, как локальная разработка!**

### 📖 Подробное руководство для разработчиков

Для полного погружения в процесс разработки с Dip и Docker, прочитайте **[DEVELOPMENT.md](DEVELOPMENT.md)** - там вы найдете:

- 🚀 Подробную настройку окружения
- 🛠️ Ежедневные команды и workflow
- 🐛 Troubleshooting частых проблем
- 🔄 CI/CD интеграцию
- 📊 Мониторинг производительности
- 🎯 Советы по продуктивности

---

# Запуск без Docker (классическая разработка)

Для локальной разработки без Docker:

### 1. Клонировать репозиторий и установить зависимости

```bash
git clone https://github.com/yourusername/auto-service-bot.git
cd auto-service-bot
bundle install
```

### 2. Настроить переменные окружения

```bash
cp .env.example .env
nano .env
```

Обязательные параметры:
```
TELEGRAM_BOT_TOKEN=your_telegram_bot_token
```

### 3. Настройка базы данных

Создание базы данных и выполнение миграций:

```bash
# Создание базы данных
rake db:create

# Выполнение миграций
rake db:migrate

# Загрузка LLM моделей
rake ruby_llm:load_models
```

### 4. Запустить бота

```bash
ruby bot.rb
```

### 5. Запуск тестов

```bash
rake test
```

### 6. Проверка стиля кода

```bash
bundle exec rubocop
```

---

Бот разрабатывается по методике Plan&Act через Claude Code AI.

## Требования

- Ruby >= 3.2.0
- Telegram Bot Token (получить можно у [@BotFather](https://t.me/botfather))
- Anthropic API Key (получить можно на [platform.anthropic.com](https://console.anthropic.com))

## Быстрый старт

### 1. Клонировать репозиторий и установить зависимости

```bash
git clone <repository>
cd auto-service-bot
bundle install
```

### 2. Настроить переменные окружения

Скопируй `.env.example` в `.env` и заполни необходимые значения:

```bash
cp .env.example .env
```

Отредактируй `.env`:

```
TELEGRAM_BOT_TOKEN=your_telegram_bot_token
ADMIN_CHAT_ID=123456789
SYSTEM_PROMPT_PATH=./system-prompt.md
RATE_LIMIT_REQUESTS=10
RATE_LIMIT_PERIOD=60
MAX_HISTORY_SIZE=10
LOG_LEVEL=info
```

### 3. Запустить бота

```bash
ruby bot.rb
```

## Архитектура приложения

```
┌─────────────────┐
│  Telegram User  │
└────────┬────────┘
         │
         │ Message
         ▼
┌──────────────────────────┐
│  TelegramBotHandler      │
│  - Слушает обновления    │
│  - Обрабатывает команды  │
└──────────┬───────────────┘
           │
           ├──▶ RateLimiter
           │    - Защита от спама
           │
           ├──▶ ConversationManager
           │    - Хранит историю диалогов
           │    - Последние 10 сообщений
           │
           └──▶ ClaudeClient
                - Отправляет запросы в Claude API
                - Обработка ошибок + 1 retry
                - Использует системный промпт
```

## Компоненты (ФАЗА 1)

### RateLimiter (`lib/rate_limiter.rb`)

Защита от спама. Ограничивает количество запросов для каждого пользователя:
- По умолчанию: 10 запросов за 60 секунд
- In-memory счетчик с автоматической очисткой старых записей

### ConversationManager (`lib/conversation_manager.rb`)

Управление историей диалогов:
- Хранит историю сообщений для каждого пользователя
- Сохраняет последние 10 сообщений (легко настроить)
- Полная очистка при команде `/start`
- Thread-safe с использованием Mutex

### ClaudeClient (`lib/claude_client.rb`)

HTTP клиент для общения с Claude API:
- Загружает системный промпт из файла
- Отправляет сообщения с контекстом диалога
- Простая обработка ошибок с 1 retry попыткой
- Парсинг JSON ответов

### TelegramBotHandler (`lib/telegram_bot_handler.rb`)

Основная логика бота:
- Слушает обновления от Telegram API
- Обрабатывает команду `/start` (очистка истории)
- Проверяет RateLimiter перед обработкой
- Отправляет запросы к Claude и возвращает ответы
- Логирует все события

### AppConfig (`config/app_config.rb`)

Управление конфигурацией через `anyway_config`:
- Загружает переменные из `.env` файла
- Валидирует обязательные параметры
- Предоставляет значения по умолчанию

## Переменные окружения

### Основные переменные приложения

| Переменная | Описание | Обязательная | По умолчанию |
|---|---|---|---|
| `OPENAI_API_BASE` | OpenAI-совместимый API endpoint (например, для z.ai) | ❌ | автоопределение |
| `SYSTEM_PROMPT_PATH` | Путь к системному промпту | ❌ | `./system-prompt.md` |
| `TELEGRAM_BOT_TOKEN` | Token Telegram бота | ✅ | - |
| `PRICE_LIST_PATH` | Путь к прайс-листу CSV | ❌ | `./data/кузник.csv` |
| `RATE_LIMIT_REQUESTS` | Кол-во запросов в лимите | ❌ | `10` |
| `RATE_LIMIT_PERIOD` | Период лимита (в сек) | ❌ | `60` |
| `MAX_HISTORY_SIZE` | Макс. размер истории | ❌ | `10` |
| `LOG_LEVEL` | Уровень логирования | ❌ | `info` |
| `ADMIN_CHAT_ID` | ID админского чата | ❌ | `123456789` |

### Переменные из gem ruby_llm (v1.8.2)

#### API ключи для различных провайдеров LLM

- `OPENAI_API_KEY` - API ключ для OpenAI
- `ANTHROPIC_API_KEY` - API ключ для Anthropic Claude
- `GEMINI_API_KEY` - API ключ для Google Gemini
- `DEEPSEEK_API_KEY` - API ключ для DeepSeek
- `PERPLEXITY_API_KEY` - API ключ для Perplexity
- `OPENROUTER_API_KEY` - API ключ для OpenRouter
- `MISTRAL_API_KEY` - API ключ для Mistral AI

#### Переменные для отладки и логирования ruby_llm

- `RUBYLLM_DEBUG` - Включение debug-логирования (любое непустое значение включает DEBUG уровень)
- `RUBYLLM_STREAM_DEBUG` - Включение debug логирования для стриминга (значение `true`)

### Пример конфигурации для z.ai

Если вы используете API от z.ai с OpenAI-совместимым endpoint:

```bash
# Вариант 1: С явным указанием OpenAI endpoint (рекомендуется)
export ANTHROPIC_AUTH_TOKEN=your_z_ai_api_key
export TELEGRAM_BOT_TOKEN=your_telegram_bot_token
export OPENAI_API_BASE=https://api.z.ai/api/paas/v4

# Запуск бота
ruby bot.rb
```

Или в `.env` файле:
```
TELEGRAM_BOT_TOKEN=your_telegram_bot_token
OPENAI_API_BASE=https://api.z.ai/api/paas/v4
LLM_PROVIDER=anthropic
LLM_MODEL=glm-4.5-air
```

При явном указании `OPENAI_API_BASE` бот будет использовать OpenAI-совместимый формат запросов, что может быть быстрее и стабильнее.

## Файловая структура

```
.
├── Gemfile                    # Зависимости проекта
├── Gemfile.lock              # Зафиксированные версии
├── Rakefile                  # Rake задачи (тесты)
├── README.md                 # Этот файл
├── .env.example              # Пример конфигурации
├── .gitignore                # Git исключения
├── bot.rb                    # Точка входа бота
├── system-prompt.md          # Системный промпт для Claude
│
├── config/
│   └── app_config.rb         # Конфигурация приложения
│
├── lib/
│   ├── claude_client.rb      # HTTP клиент для Claude API
│   ├── telegram_bot_handler.rb # Обработка Telegram сообщений
│   ├── conversation_manager.rb # Управление историей диалогов
│   └── rate_limiter.rb       # Защита от спама
│
├── test/
│   ├── test_helper.rb        # Конфиг для тестов
│   ├── test_rate_limiter.rb
│   ├── test_claude_client.rb
│   ├── test_conversation_manager.rb
│   └── test_app_config.rb
│
├── .protocols/
│   └── plan.md               # Детальный план реализации
│
└── data/
    └── кузник.csv            # Прайс-лист услуг
```

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

## Использование системного промпта

Системный промпт загружается из файла `system-prompt.md` и комбинируется с отформатированным прайс-листом. Это позволяет задать контекст и поведение бота для обработки запросов о услугах автосервиса с актуальными ценами.

Формат запроса к API:

```json
{
  "model": "glm-4.5-air",
  "max_tokens": 1500,
  "system": "Содержимое системного промпта + отформатированный прайс-лист...",
  "messages": [
    {"role": "user", "content": "Первое сообщение"},
    {"role": "assistant", "content": "Ответ Claude"},
    ...
  ]
}
```

## Тесты

Запуск всех тестов:

```bash
rake test
```

Тесты покрывают:
- RateLimiter (6 тестов)
- ConversationManager (7 тестов)
- ClaudeClient (3 теста)
- AppConfig (5 тестов)

Итого: 21 unit тест

## Обработка ошибок

Бот имеет встроенную обработку ошибок:
- Ошибки API Claude: простой rescue блок + 1 retry попытка
- Ошибки Telegram API: обработка с отправкой сообщения об ошибке
- Все ошибки логируются с уровнем `error` или `warn`

## Следующие шаги (ФАЗА 2)

После успешного запуска MVP, планируется добавить:

- MessageHandlers с паттерном Strategy
- TokenManager с точным подсчетом токенов
- Circuit Breaker для отказоустойчивости
- StructuredLogger для JSON логирования
- AsyncMessageProcessor для неблокирующей обработки
- Metrics и health checks
- Prompt caching для оптимизации стоимости
- Graceful shutdown

Детали см. в `.protocols/plan.md` и `.protocols/plan-must-have.md`

## Лицензия

Этот проект распространяется под лицензией Mozilla Public License 2.0 (MPL-2.0).

### Основные положения лицензии:

- **Разрешает коммерческое использование** - вы можете использовать этот проект в коммерческих целях
- **Требует предоставления исходного кода** - если вы вносите изменения в код под MPL, вы должны предоставить исходный код этих изменений
- **Слабое копилефт** - требования распространяются только на измененные файлы, а не на весь проект
- **Сохранение авторства** - вы должны указать оригинального автора и лицензию
- **Патентная защита** - предоставляет патентные права для пользователей

Подробный текст лицензии доступен в файле [LICENSE](LICENSE).

## Контакты

Для вопросов и предложений обратитесь к разработчику.
