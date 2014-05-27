# encoding: utf-8

require 'rack/session/abstract/id'
require 'thread'
require 'rethinkdb'

module Rack
  module Session
    class RethinkDB < Abstract::ID
      DEFAULT_OPTIONS = Abstract::ID::DEFAULT_OPTIONS.merge \
                          port: 28_015, table: 'sessions'

      attr_reader :mutex, :pool, :host, :port, :db, :table

      # @see Rack::Session#initialize
      #
      # @param [Hash<Symbol,Object>] options
      # @option options [String] :host hostname or IP for RethinkDB server
      #                                (required)
      # @option options [Integer] :port port number for the RethinkDB server
      #                                 (default: 28015)
      # @option options [String] :db database name (required)
      # @option options [String] :table table name to store sessions in
      #                                 (default: 'sessions')
      def initialize(app, options = {})
        super
        @host  = options[:host]
        @port  = @default_options[:port]
        @db    = @default_options[:db]
        @table = @default_options[:table]

        @mutex = Mutex.new
      end

      def generate_sid
        loop do
          sid = super
          break sid unless _exists?(sid)
        end
      end

      def get_session(env, sid)
        with_lock(env, [nil, {}]) do
          unless sid && (session = _get(sid))
            sid, session = generate_sid, {}
            _put(sid, session)
          end

          [sid, session]
        end
      end

      def set_session(env, session_id, new_session, _options)
        with_lock(env, false) do
          _put(session_id, new_session)
          session_id
        end
      end

      def destroy_session(env, session_id, options)
        with_lock(env) do
          # @pool.del(session_id)
          ::RethinkDB::RQL.new.db(db).table(table).get(session_id).delete
            .run(connection)
          generate_sid unless options[:drop]
        end
      end

      def with_lock(env, default = nil)
        mutex.lock if env['rack.multithread']
        yield
      rescue
        default
      ensure
        mutex.unlock if mutex.locked?
      end

      private

      # @return [RethinkDB::Connection]
      def connection
        @connection ||= ::RethinkDB::RQL.new.connect(host: host, port: port)
      rescue Exception => err
        $stderr.puts("Cannot connect to database: #{err.message}")
      end

      # Handle to the RethinkDB::RQL query DSL helper
      #
      # @return [RethinkDB::RQL]
      def r
        @r ||= ::RethinkDB::RQL.new
      end

      def _exists?(sid)
        !_get(sid).nil?
      end

      def _get(sid)
        record = r.db(db).table(table).get(sid).run(connection)
        return unless record
        Marshal.load(record['data'].unpack('m*').first)
      end

      def _put(sid, session)
        data = {
          id: sid,
          updated_at: Time.now,
          data: [Marshal.dump(session)].pack('m*')
        }

        r.db(db).table(table).insert(data, upsert: true).run(connection)
      end
    end
  end
end
