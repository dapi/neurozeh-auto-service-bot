require_relative 'boot'
require_relative 'database'
require_relative 'app_config'
require_relative 'application'
require_relative 'initialize'

# Инициализация базы данных

DatabaseConfig.setup
# Загрузка моделей после установки соединения с БД
ActiveRecord::Base.include RubyLLM::ActiveRecord::ActsAs
DatabaseConfig.load_models


Application.initialize!
Application.instance.logger.info 'Auto Service Bot starting...'
Application.instance.logger.info 'Bot initialized successfully'
