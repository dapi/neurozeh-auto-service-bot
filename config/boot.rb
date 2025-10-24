ENV['BUNDLE_GEMFILE'] ||= File.expand_path('../Gemfile', __dir__)
require 'bundler/setup'
Bundler.require
require 'rails/all'
require 'logger'
require 'ostruct'
