# encoding: utf-8

require 'bundler/setup'
Bundler.require
require 'rake/clean'
require 'rubygems/package_task'

load 'tasks/db.rake'

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec) do |t|
  t.rspec_opts = %w(-fs --color)
end

task default: ['db:reset', :spec]

desc 'Build'
task build: [:clean, :doc, :gem]

gemspec = Gem::Specification.load('rack-session-rethinkdb.gemspec')

Gem::PackageTask.new(gemspec) do |pkg|
end

CLEAN.include(['pkg', '*.gem', '.yardoc'])
