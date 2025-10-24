ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)
require 'bundler/setup'
Bundler.require(:default, :development)
require 'logger'
require 'ostruct'
