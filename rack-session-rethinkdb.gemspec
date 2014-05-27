# encoding: utf-8

Gem::Specification.new do |s|
  s.name        = 'rack-session-rethinkdb'
  s.version     = '0.1.0'
  s.authors     = ['Paul Dlug']
  s.email       = 'paul.dlug@gmail.com'
  s.homepage    = 'http://github.com/pdlug/rack-session-rethinkdb'
  s.summary     = 'Rack session storage in RethinkDB'
  s.description = 'Provides a rack session middleware to store sessions in a RethinkDB table.'

  s.require_path  = 'lib'
  s.files         = %w(README.md Rakefile CHANGELOG.md) + Dir['{lib,spec}/**/*']
  s.require_paths = ['lib']

  s.add_runtime_dependency 'rack'
  s.add_runtime_dependency 'rethinkdb'

  s.add_development_dependency 'rake'
  s.add_development_dependency 'rspec'
end