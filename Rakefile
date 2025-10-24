# frozen_string_literal: true

require 'standalone_migrations'
require 'rake/testtask'
require 'rubocop/rake_task'

StandaloneMigrations::Tasks.load_tasks(name: 'auto-service-bot')

task default: %i[test rubocop]

Rake::TestTask.new do |t|
  t.libs << 'test'
  t.pattern = 'test/test_*.rb'
  t.verbose = true
end

RuboCop::RakeTask.new do |task|
  task.options = ['--format', 'simple']
end
