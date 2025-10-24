ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)
require 'bundler/setup'
Bundler.require(:default, :development)
require 'logger'
require 'ostruct'

# Load RubyLLM initializer
require_relative 'initializers/ruby_llm'
