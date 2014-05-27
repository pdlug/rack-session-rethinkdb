# encoding: utf-8

require 'rethinkdb'

namespace :db do
  desc 'Tear down and recreate the test DB'
  task :reset do
    r = RethinkDB::RQL.new

    db_host = '127.0.0.1'
    db_port = 28015
    db_name = 'rack_session_rethinkdb_test'

    begin
      connection = r.connect(host: db_host, port: db_port)
    rescue => e
      $stderr.puts("\e[31mERROR\e[0m: RethinkDB running on #{db_host}:#{db_port} required to run tests: #{e.message}")
      exit(1)
    end

    begin
      r.db_drop(db_name).run(connection)
    rescue RethinkDB::RqlRuntimeError
    end

    begin
      r.db_create(db_name).run(connection)
    rescue RethinkDB::RqlRuntimeError
    end

    %w(sessions my_session_table_test).each do |table|
      begin
        r.db(db_name).table_create(table).run(connection)
      rescue RethinkDB::RqlRuntimeError
      end
    end
  end
end
