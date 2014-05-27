# encoding: utf-8
require File.expand_path('./spec_helper.rb', File.dirname(__FILE__))

require 'rack/session/rethinkdb'
require 'rack/mock'

def get_sid(response)
  /#{session_key}=(.+?)\W/.match(response['Set-Cookie'])[1]
end

describe Rack::Session::RethinkDB do
  let(:db_name) { 'rack_session_rethinkdb_test' }
  let(:config) { { host: '127.0.0.1', port: 28015, db: db_name } }
  let(:session_key) { Rack::Session::RethinkDB::DEFAULT_OPTIONS[:key] }
  let(:default_table) { Rack::Session::RethinkDB::DEFAULT_OPTIONS[:table] }
  let(:session_match) { /#{session_key}=[0-9a-fA-F]+;/ }

  let(:connection) do
    RethinkDB::RQL.new.connect(host: '127.0.0.1', port: 28015)
  end

  let!(:incrementor) do
    lambda do |env|
      env['rack.session']['counter'] ||= 0
      env['rack.session']['counter'] += 1
      Rack::Response.new(env['rack.session'].inspect).to_a
    end
  end

  describe 'configuration' do
    describe 'when :table is specified' do
      let(:table) { 'my_session_table_test' }
      let(:pool) do
        Rack::Session::RethinkDB.new(incrementor, config.merge(table: table))
      end
      let(:response) { Rack::MockRequest.new(pool).get('/') }
      let(:sid) { /#{session_key}=(.+?)\W/.match(response['Set-Cookie'])[1] }
      let(:record) do
        RethinkDB::RQL.new.db(db_name).table(table).get(sid).run(connection)
      end

      it 'writes the session to the named table' do
        expect(record).to include('id' => sid)
      end
    end
  end

  describe 'when no session cookie is set' do
    let(:pool) { Rack::Session::RethinkDB.new(incrementor, config) }
    let(:response) { Rack::MockRequest.new(pool).get('/') }

    it 'sets a cookie' do
      expect(response['Set-Cookie']).to match(/#{session_key}=.+/)
    end

    describe 'persistence' do
      let(:sid) { get_sid(response) }
      let(:record) do
        RethinkDB::RQL.new.db(db_name).table(default_table)
          .get(sid).run(connection)
      end

      it 'writes a document for the session' do
        expect(record).to include('id' => sid)
      end

      it 'persists the session data as a base64 encoded marshalled array' do
        data = Marshal.load(record['data'].unpack('m*').first)

        expect(data).to include('counter' => 1)
      end

      it 'sets the updated_at timestamp' do
        expect(record['updated_at']).to be_a_kind_of(Time)
        expect(record['updated_at']).to be_within(1).of(Time.now)
      end
    end
  end

  context 'when a session cookie is present' do
    context 'when the session ID is found in the database' do
      let(:pool) { Rack::Session::RethinkDB.new(incrementor, config) }
      let(:request) { Rack::MockRequest.new(pool) }
      let(:response) do
        cookie = request.get('/')['Set-Cookie']
        request.get('/', 'HTTP_COOKIE' => cookie)
      end

      it 'sets the serialized session data on the request' do
        expect(response.body).to eq('{"counter"=>2}')
      end

      it 'does not resend the session id' do
        expect(response['Set-Cookie']).to be_nil
      end
    end

    context 'when the session has expired' do
    end

    context 'when the session ID is not found in the database' do
      let(:pool) { Rack::Session::RethinkDB.new(incrementor, config) }
      let(:request) { Rack::MockRequest.new(pool) }
      let(:bad_sid) { 'foobarbaz' }
      let(:response) do
        request.get('/', 'HTTP_COOKIE' => "#{session_key}=#{bad_sid}")
      end
      let(:sid) { get_sid(response) }

      it 'sets up fresh session data' do
        expect(response.body).to eq('{"counter"=>1}')
      end

      it 'sets a new session ID' do
        expect(sid).not_to eq(bad_sid)
      end
    end
  end

  describe 'rack.session.options' do
    context 'when :drop is set' do
      let!(:drop_session) do
        Rack::Lint.new(lambda do |env|
          env['rack.session.options'][:drop] = true
          incrementor.call(env)
        end)
      end
      let(:pool) { Rack::Session::RethinkDB.new(incrementor, config) }
      let(:request) { Rack::MockRequest.new(pool) }
      let(:drop_request) do
        Rack::MockRequest.new(Rack::Utils::Context.new(pool, drop_session))
      end

      it 'deletes cookies with :drop option' do
        res1 = request.get('/')
        session = (cookie = res1['Set-Cookie'])[session_match]
        expect(res1.body).to eq('{"counter"=>1}')

        res2 = drop_request.get('/', 'HTTP_COOKIE' => cookie)
        expect(res2['Set-Cookie']).to be_nil
        expect(res2.body).to eq('{"counter"=>2}')

        res3 = request.get('/', 'HTTP_COOKIE' => cookie)
        expect(res3['Set-Cookie'][session_match]).not_to eq(session)
        expect(res3.body).to eq('{"counter"=>1}')
      end
    end

    context 'when :renew is set' do
      let!(:renew_session) do
        Rack::Lint.new(lambda do |env|
          env['rack.session.options'][:renew] = true
          incrementor.call(env)
        end)
      end
      let(:pool) { Rack::Session::RethinkDB.new(incrementor, config) }
      let(:request) { Rack::MockRequest.new(pool) }
      let(:renew_request) do
        Rack::MockRequest.new(Rack::Utils::Context.new(pool, renew_session))
      end

      it 'provides a new session ID' do
        res1 = request.get('/')
        session = (cookie = res1['Set-Cookie'])[session_match]
        expect(res1.body).to eq('{"counter"=>1}')

        res2 = renew_request.get('/', 'HTTP_COOKIE' => cookie)
        new_cookie = res2['Set-Cookie']
        new_session = new_cookie[session_match]
        expect(new_session).not_to eq(session)
        expect(res2.body).to eq('{"counter"=>2}')

        res3 = request.get('/', 'HTTP_COOKIE' => new_cookie)
        expect(res3.body).to eq('{"counter"=>3}')

        res4 = request.get('/', 'HTTP_COOKIE' => cookie)
        expect(res4.body).to eq('{"counter"=>1}')
      end

      it 'deletes the original session' do
        res1 = request.get('/')
        original_sid = get_sid(res1)
        cookie = res1['Set-Cookie'][session_match]
        res2 = renew_request.get('/', 'HTTP_COOKIE' => cookie)

        expect(RethinkDB::RQL.new.db(db_name).table(default_table)
          .get(original_sid).run(connection)).to be_nil
      end
    end

    context 'when :defer is set' do
      let(:pool) { Rack::Session::RethinkDB.new(incrementor, config) }
      let!(:defer_session) do
        Rack::Lint.new(lambda do |env|
          env['rack.session.options'][:defer] = true
          incrementor.call(env)
        end)
      end

      let(:defer_request) do
        Rack::MockRequest.new(Rack::Utils::Context.new(pool, defer_session))
      end

      it 'omits the cookie' do
        res1 = defer_request.get('/')
        expect(res1['Set-Cookie']).to be_nil
        expect(res1.body).to eq('{"counter"=>1}')
      end
    end
  end
end
