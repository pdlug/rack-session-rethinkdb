# encoding: utf-8

require 'bundler/setup'
Bundler.require

require 'rspec'

$LOAD_PATH.unshift File.expand_path('../lib', File.dirname(__FILE__))

RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
