# rack-session-rethinkdb

Store rack sessions in a RethinkDB table.

## Installation

    gem install rack-session-rethinkdb

The database and table to be used for storage must be created prior to use. The database name must be provided, the table name will default to `sessions` unless an alternate is specified.

## Usage

Sessions will be stored in the table `sessions` by default. The hostname/IP and
database name must be specified and must exist.

    require 'rack/session/rethinkdb'

    use Rack::Session::RethinkDB, {
      host:  '127.0.0.1',  # required
      db:    'myapp',      # required
      port:  28015,        # optional (default: 28015)
      table: 'sessions'    # optional (default: 'sessions')
    }