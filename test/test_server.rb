# frozen_string_literal: true

require_relative './helper'

class ServerTest < Minitest::Test
  def make_socket_pair
    port = 10000 + rand(30000)
    server_fd = @machine.socket(UM::AF_INET, UM::SOCK_STREAM, 0, 0)
    @machine.setsockopt(server_fd, UM::SOL_SOCKET, UM::SO_REUSEADDR, true)
    @machine.bind(server_fd, '127.0.0.1', port)
    @machine.listen(server_fd, UM::SOMAXCONN)

    client_conn_fd = @machine.socket(UM::AF_INET, UM::SOCK_STREAM, 0, 0)
    @machine.connect(client_conn_fd, '127.0.0.1', port)

    server_conn_fd = @machine.accept(server_fd)

    @machine.close(server_fd)
    [client_conn_fd, server_conn_fd]
  end

  class STOP < StandardError
  end

  def setup(opts = {})
    @machine = UM.new
    @port = 10000 + rand(30000)
    @env = { bind: "127.0.0.1:#{@port}" }.merge(opts)
    @server = Syntropy::HTTP::Server.new(@machine, @env) { @app&.call(it) }
    @f_server = @machine.spin { run_server }

    # let server spin and listen to incoming connections
    @machine.sleep(0.01)

    @client_fd = @machine.socket(UM::AF_INET, UM::SOCK_STREAM, 0, 0)
    @machine.connect(@client_fd, '127.0.0.1', @port)
  end

  def run_server
    @server.run
  ensure
    @server_done = true
  end

  def teardown
    @machine.close(@client_fd) rescue nil
    @server.stop!
    @machine.snooze until @server_done
  end

  def write_http_request(msg)
    @machine.send(@client_fd, msg, msg.bytesize, UM::MSG_WAITALL)
  end

  def write_client_side(msg)
    @machine.send(@client_fd, msg, msg.bytesize, UM::MSG_WAITALL)
  end

  def read_client_side(len = 65536)
    buf = +''
    res = @machine.recv(@client_fd, buf, len, 0)
    res == 0 ? nil : buf
  end

  def test_http_1_0_response
    @app = ->(req) {
      req.respond('Hello, world!', {})
    }

    write_http_request "GET / HTTP/1.0\r\n\r\n"
    response = read_client_side
    expected = "HTTP/1.1 505\r\nTransfer-Encoding: chunked\r\n\r\n1a\r\nHTTP version not supported\r\n0\r\n\r\n"
    assert_equal(expected, response)
  end

  def test_basic_app_response
    @app = ->(req) {
      req.respond('Hello, world!', {})
    }

    write_http_request "GET / HTTP/1.1\r\n\r\n"
    response = read_client_side
    expected = "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\n\r\nd\r\nHello, world!\r\n0\r\n\r\n"
    assert_equal(expected, response)
  end

  def test_pipelined_requests
    @app = ->(req) {
      req.respond("method: #{req.method}")
    }

    write_http_request "GET /foo HTTP/1.1\r\nServer: foo.com\r\n\r\nPUT /bar HTTP/1.1\r\n\r\n"

    @machine.sleep(0.1)
    response = read_client_side
    expected = "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\n\r\nb\r\nmethod: get\r\n0\r\n\r\n" +
               "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\n\r\nb\r\nmethod: put\r\n0\r\n\r\n"
    assert_equal(expected, response)
  end

  def test_graceful_shutdown
    @app = ->(req) do
      @machine.sleep(1)
      req.respond('Hello, world!', {})
    rescue UM::Terminate
      req.respond('Terminated!', {})
      raise
    end

    write_http_request "GET /foo HTTP/1.1\r\nServer: foo.com\r\n\r\nPUT /bar HTTP/1.1\r\n\r\n"

    @machine.sleep(0.01)
    @server.stop!
    @machine.snooze

    response = read_client_side
    expected = "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\n\r\nb\r\nTerminated!\r\n0\r\n\r\n"
    assert_equal(expected, response)
  end

  def test_pipelined_requests_with_body
    @bodies = []
    @reqs = []
    @app = ->(req) {
      @reqs << req
      @bodies << req.read
      req.respond("method: #{req.method}")
    }

    msg = <<~HTTP.crlf_lines
      POST /foo HTTP/1.1
      Server: foo.com
      Content-Length: 3

      abcPOST /bar HTTP/1.1
      Server: bar.com
      Content-Length: 6

      defghi
    HTTP
    write_http_request msg

    read_client_side
    assert_equal 2, @bodies.size

    req0 = @reqs.shift
    headers = req0.headers
    assert_equal({
      ':method' => 'post',
      ':path' => '/foo',
      'server' => 'foo.com',
      'content-length' => '3',
      ':body-done-reading' => true
    }, headers)
    body = @bodies.shift
    assert_equal 'abc', body

    req1 = @reqs.shift
    headers = req1.headers
    assert_equal({
      ':method' => 'post',
      ':path' => '/bar',
      'server' => 'bar.com',
      'content-length' => '6',
      ':body-done-reading' => true
    }, headers)
    body = @bodies.shift
    assert_equal 'defghi', body
  end

  def test_pipelined_requests_with_body_chunked
    @bodies = []
    @reqs = []
    @app = ->(req) do
      @reqs << req
      @bodies << (b = req.read)
      req.respond("method: #{req.method}")
    rescue => e
      p e
      p e.backtrace
      exit!
    end

    msg = <<~HTTP.crlf_lines
      POST /foo HTTP/1.1
      Server: foo.com
      Transfer-Encoding: chunked

      3
      abc
      2
      de
      0

      POST /bar HTTP/1.1
      Server: bar.com
      Transfer-Encoding: chunked

      1f
      123456789abcdefghijklmnopqrstuv
      0



    HTTP

    write_http_request msg
    read_client_side
    read_client_side
    assert_equal 2, @bodies.size

    req0 = @reqs.shift
    headers = req0.headers
    assert_equal({
      ':method'             => 'post',
      ':path'               => '/foo',
      'server'              => 'foo.com',
      'transfer-encoding'   => 'chunked',
      ':body-done-reading'  => true
    }, headers)
    body = @bodies.shift
    assert_equal 'abcde', body

    req1 = @reqs.shift
    headers = req1.headers
    assert_equal({
      ':method'             => 'post',
      ':path'               => '/bar',
      'server'              => 'bar.com',
      'transfer-encoding'   => 'chunked',
      ':body-done-reading'  => true
    }, headers)
    body = @bodies.shift
    assert_equal '123456789abcdefghijklmnopqrstuv', body
  end

  class TestLogger
    attr_reader :entries

    def initialize
      @entries = []
    end

    def info(o)
      @entries << o.merge(level: :INFO)
    end

    def error(o)
      @entries << o.merge(level: :ERROR)
    end
  end

  def test_logging
    skip
    reqs = []
    @env[:logger] = TestLogger.new
    @app = ->(req) { reqs << req; req.respond('Hello, world!', {}) }

    write_http_request "GET / HTTP/1.1\r\n\r\n"
    response = read_client_side
    expected = "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\n\r\nd\r\nHello, world!\r\n0\r\n\r\n"
    assert_equal(expected, response)

    entries = @env[:logger].entries
    assert_equal 1, entries.size
    assert_equal 1, reqs.size

    assert_equal reqs.first, entries.first[:request]
  end

  def test_server_headers
    @env[:server_headers] = "Server: Tipi\r\n"

    @app = ->(req) {
      req.respond('Hello, world!', {})
    }

    write_http_request "GET / HTTP/1.1\r\n\r\n"
    response = read_client_side
    expected = "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\nServer: Tipi\r\n\r\nd\r\nHello, world!\r\n0\r\n\r\n"
    assert_equal(expected, response)
  end

  def test_server_headers_date
    setup({ server_extensions: { date: true } })
    @machine.sleep(0.1)
    assert_kind_of Time, @env[:server_date]

    @app = ->(req) {
      req.respond('foo', {})
    }

    write_http_request "GET / HTTP/1.1\r\n\r\n"
    response = read_client_side
    expected = "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\nDate: #{@env[:server_date].httpdate}\r\n\r\n3\r\nfoo\r\n0\r\n\r\n"
    assert_equal(expected, response)
  end

  def test_server_headers_date_and_server_name
    setup({ server_extensions: { date: true, name: 'Foo' } })
    @machine.sleep(0.1)
    assert_kind_of Time, @env[:server_date]

    @app = ->(req) {
      req.respond('foo', {})
    }

    write_http_request "GET / HTTP/1.1\r\n\r\n"
    response = read_client_side
    expected = "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\nServer: Foo\r\nDate: #{@env[:server_date].httpdate}\r\n\r\n3\r\nfoo\r\n0\r\n\r\n"
    assert_equal(expected, response)
  end

  def test_server_headers_server_name
    setup({ server_extensions: { name: 'Bar' } })
    @machine.sleep(0.1)
    assert_nil @env[:server_date]

    @app = ->(req) {
      req.respond('foo', {})
    }

    write_http_request "GET / HTTP/1.1\r\n\r\n"
    response = read_client_side
    expected = "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\nServer: Bar\r\n\r\n3\r\nfoo\r\n0\r\n\r\n"
    assert_equal(expected, response)
  end
end
