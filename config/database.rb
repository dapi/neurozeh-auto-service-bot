# frozen_string_literal: true

require 'active_record'
require 'yaml'

module DatabaseConfig
  def self.setup
    environment = ENV['RAILS_ENV'] || 'development'
    db_config = YAML.load_file(File.join(File.dirname(__FILE__), '..', 'db', 'config.yml'))[environment]

    ActiveRecord::Base.establish_connection(db_config)
    ActiveRecord::Base.logger = ::Logger.new($stdout) if ENV['DEBUG']
  end

  def self.load_models
    # Загрузка базового класса первой
    require File.join(File.dirname(__FILE__), '..', 'app', 'models', 'application_record')

    # Загрузка остальных моделей
    Dir[File.join(File.dirname(__FILE__), '..', 'app', 'models', '*.rb')].each do |f|
      next if f.include?('application_record')
      require f
    end
  end
end
