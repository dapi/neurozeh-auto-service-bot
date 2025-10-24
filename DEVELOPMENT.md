# Руководство по разработке с Dip

Это руководство поможет вам настроить эффективную среду разработки для Neurozeh Auto Service Bot с использованием Dip.

## 🚀 Быстрая настройка (для опытных разработчиков)

```bash
# 1. Клонировать репозиторий
git clone https://github.com/yourusername/auto-service-bot.git
cd auto-service-bot

# 2. Установить зависимости
bundle install

# 3. Установить Dip
bundle exec gem install dip

# 4. Настроить окружение
dip setup

# 5. Запустить разработку
dip up
dip bash
```

## 📋 Подробная настройка

### Шаг 1: Установка пред requisite

**Ruby и Bundler:**
```bash
# Убедитесь, что у вас установлен Ruby >= 3.2.0
ruby --version

# Установите Bundler если еще не установлен
gem install bundler
```

**Docker и Docker Compose:**
```bash
# Проверьте установку
docker --version
docker-compose --version

# Если не установлены, установите с https://docker.com
```

### Шаг 2: Установка Dip

```bash
# Способ 1: Глобальная установка
gem install dip

# Способ 2: Через Bundler (рекомендуется)
bundle add dip --group development
bundle install
```

### Шаг 3: Настройка окружения

```bash
# Скопировать файл конфигурации
cp .env.example .env

# Отредактировать .env с вашими токенами
nano .env
```

Обязательно заполните:
```
ANTHROPIC_AUTH_TOKEN=your_anthropic_api_key
TELEGRAM_BOT_TOKEN=your_telegram_bot_token
```

### Шаг 4: Проверка настройки

```bash
# Проверить конфигурацию Dip
dip validate

# Показать все доступные команды
dip ls

# Запустить provisioning (первоначальная настройка)
dip provision
```

## 🛠️ Ежедневная работа с Dip

### Основной workflow

```bash
# 1. Запустить окружение
dip up

# 2. Открыть shell в контейнере
dip bash

# 3. Внутри контейнера вести разработку:
#    - Редактировать код
#    - Устанавливать gems
#    - Запускать тесты
#    - Работать с ботом

# 4. Остановить окружение
dip down
```

### Продвинутая работа с Shell интеграцией

```bash
# Включить shell интеграцию (добавить в ~/.zshrc или ~/.bashrc)
echo 'eval "$(dip console)"' >> ~/.zshrc
source ~/.zshrc

# Теперь можно выполнять команды без префикса dip:
bash                # Открыть shell в контейнере
bundle install       # Установить gems
rake test          # Запустить тесты
logs               # Смотреть логи
```

### Команды разработки

#### Работа с кодом
```bash
dip bash                    # Открыть shell
dip bundle install          # Установить gems
dip bundle update           # Обновить gems
dip rubocop                 # Проверить стиль кода
dip rubocop-autocorrect     # Исправить стиль кода
```

#### Тестирование
```bash
dip test                    # Запустить все тесты
dip minitest test/file.rb   # Запустить конкретный тест
dip rake test               # Альтернативный способ запуска тестов
```

#### Работа с ботом
```bash
dip bot                     # Запустить бота
dip bot-console             # Запустить с консолью отладки
dip restart                # Перезапустить бота
dip logs                   # Смотреть логи в реальном времени
```

#### Управление окружением
```bash
dip health                  # Проверить состояние
dip clean                   # Очистить Docker ресурсы
dip down && dip up         # Полная перезагрузка
```

## 🐛 Отладка и Troubleshooting

### Проблемы с правами доступа

Если возникают проблемы с правами на файлах:

```bash
# Узнать свой UID/GID
id -u
id -g

# Запустить с правильными UID/GID
UID=$(id -u) GID=$(id -g) dip up
```

### Проблемы с зависимостями

```bash
# Пересобрать контейнер с чистым состоянием
dip down
docker-compose down --volumes
dip up

# Очистить bundle cache
dip bash -c "rm -rf vendor/bundle && bundle install"
```

### Проблемы с сетью

```bash
# Проверить сетевые настройки
dip bash -c "curl -v google.com"

# Перезапустить Docker сеть
docker network prune
dip down && dip up
```

### Просмотр логов для отладки

```bash
# Все логи
dip logs

# Логи конкретного сервиса
dip logs auto-service-bot

# Логи с меткой времени
dip logs -t

# Последние 100 строк
dip logs --tail=100
```

## 🔄 CI/CD интеграция

### Перед коммитом

```bash
# Полная проверка перед коммитом
dip rubocop
dip test
```

### Автоматизация через git hooks

Создайте `.git/hooks/pre-commit`:
```bash
#!/bin/bash
dip rubocop || exit 1
dip test || exit 1
```

Сделайте исполняемым:
```bash
chmod +x .git/hooks/pre-commit
```

## 📊 Мониторинг производительности

### Использование ресурсов

```bash
# Мониторинг контейнера
docker stats auto-service-bot

# Размер образов
docker images | grep auto-service

# Очистка неиспользуемых ресурсов
docker system prune
```

### Профилирование Ruby кода

```bash
# Запустить с профилированием
dip bash -c "ruby-prof -p graph_html bot.rb"
```

## 🚀 Советы по продуктивности

### 1. Горячие клавиши в shell

Добавьте в `~/.zshrc` или `~/.bashrc`:
```bash
# Dip aliases
alias db='dip bash'
alias dl='dip logs'
alias dr='dip restart'
alias dt='dip test'
```

### 2. Быстрый рестарт

```bash
# Быстрый перезапуск бота с пересборкой
dip down && dip up && dip bot
```

### 3. Работа с несколькими терминалами

```bash
# Терминал 1: Логи
dip logs -f

# Терминал 2: Разработка
dip bash

# Терминал 3: Тестирование
dip minitest test/test_file.rb
```

### 4. Работа с Git

```bash
# Проверить стиль перед коммитом
dip rubocop && git add .

# Запустить тесты перед push
git push && dip test
```

## 📝 Дополнительные ресурсы

- [Dip Documentation](https://github.com/bibendi/dip)
- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [Ruby on Docker Best Practices](https://docs.docker.com/develop/develop-images/ruby/)

## 🆘 Поддержка

Если у вас возникли проблемы:

1. Проверьте [Issues](https://github.com/yourusername/auto-service-bot/issues)
2. Создайте новый Issue с подробным описанием
3. Приложите вывод `dip health` и `dip validate`

---

**Удачной разработки с Dip!** 🎉