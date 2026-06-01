# frozen_string_literal: true

require_relative './helper'
require 'securerandom'

class HTTPServerConnectionTest < Minitest::Test
  def make_socket_pair
    port = SecureRandom.random_number(10000..40000)
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

  def setup
    @machine = UM.new
    @c_fd, @s_fd = make_socket_pair
    # s = @machine.io(@s_fd, :socket)

    @reqs = []
    @hook = nil
    @app = ->(req) { @reqs << req; @hook&.call(req) }
    @env = {}
    @connection = Syntropy::HTTP::ServerConnection.new(@machine, @s_fd, @env, &@app)
  end

  def teardown
    @machine.close(@c_fd) rescue nil
    @machine.close(@s_fd) rescue nil
  end

  def write_http_request(msg, shutdown_wr = true)
    @machine.send(@c_fd, msg, msg.bytesize, UM::MSG_WAITALL)
    @machine.shutdown(@c_fd, UM::SHUT_WR) if shutdown_wr
  end

  def write_client_side(msg)
    @machine.send(@c_fd, msg, msg.bytesize, UM::MSG_WAITALL)
  end

  def read_client_side(len = 65536)
    buf = +''
    res = @machine.recv(@c_fd, buf, len, 0)
    res == 0 ? nil : buf
  end

  def test_http_unsupported_versions
    write_http_request "GET / HTTP/0.9\r\n\r\n"
    @connection.serve_request
    response = read_client_side
    assert_equal "HTTP/1.1 505\r\nTransfer-Encoding: chunked\r\n\r\n1a\r\nHTTP version not supported\r\n0\r\n\r\n", response

    setup

    write_http_request "GET / HTTP/1.0\r\n\r\n"
    @connection.serve_request
    response = read_client_side
    assert_equal "HTTP/1.1 505\r\nTransfer-Encoding: chunked\r\n\r\n1a\r\nHTTP version not supported\r\n0\r\n\r\n", response

    setup

    @hook = ->(req) { req.respond('hi') }
    write_http_request "GET / HTTP/1.1\r\n\r\n"
    @connection.serve_request
    @machine.close(@s_fd)
    response = read_client_side
    assert_equal "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\n\r\n2\r\nhi\r\n0\r\n\r\n", response
  end

  def test_basic_request_parsing
    write_http_request "GET / HTTP/1.1\r\n\r\n"

    @connection.serve_request
    assert_equal 1, @reqs.size
    req = @reqs.shift
    headers = req.headers
    assert_equal({
      ':method'   => 'get',
      ':path'     => '/'
    }, headers)
  end

  def test_pipelined_requests
    msg = <<~HTTP.crlf_lines
      GET /foo HTTP/1.1
      Server: foo.com

      GET /bar HTTP/1.1



    HTTP
    write_http_request msg

    @connection.run
    assert_equal 2, @reqs.size
    req0 = @reqs.shift
    headers = req0.headers
    assert_equal({
      ':method'   => 'get',
      ':path'     => '/foo',
      'server'    => 'foo.com'
    }, headers)

    req1 = @reqs.shift
    headers = req1.headers
    assert_equal({
      ':method'   => 'get',
      ':path'     => '/bar'
    }, headers)
  end

  def test_pipelined_requests_with_body
    write_http_request <<~HTTP.crlf_lines
      POST /foo HTTP/1.1
      Server: foo.com
      Content-Length: 3

      abcPOST /bar HTTP/1.1
      Server: bar.com
      Content-Length: 6

      defghi
    HTTP

    @bodies = []
    @hook = ->(req) { @bodies << req.read }

    @connection.run
    assert_equal 2, @reqs.size

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
    write_http_request(msg)

    @bodies = []
    @hook = ->(req) { @bodies << req.read }

    @connection.run
    assert_equal 2, @reqs.size

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

  def test_each_chunk
    write_http_request <<~HTTP.crlf_lines
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
      Content-Length: 31

      123456789abcdefghijklmnopqrstuv
    HTTP

    chunks = []
    @hook = ->(req) { req.each_chunk { chunks << it } }

    @connection.serve_request
    assert_equal 1, @reqs.size

    req0 = @reqs.shift
    headers = req0.headers
    assert_equal({
      ':method'             => 'post',
      ':path'               => '/foo',
      'server'              => 'foo.com',
      'transfer-encoding'   => 'chunked',
      ':body-done-reading'  => true
    }, headers)
    assert_equal ['abc', 'de'], chunks

    chunks.clear
    @connection.serve_request
    assert_equal 1, @reqs.size

    req1 = @reqs.shift
    headers = req1.headers
    assert_equal({
      ':method'             => 'post',
      ':path'               => '/bar',
      'server'              => 'bar.com',
      'content-length'      => '31',
      ':body-done-reading'  => true
    }, headers)
    assert_equal ['123456789abcdefghijklmnopqrstuv'], chunks
  end

  def test_204_status_on_empty_response
    @hook = ->(req) {
      req.respond(nil, {})
    }

    write_http_request "GET / HTTP/1.1\r\n\r\n"
    @connection.run
    response = read_client_side

    expected = <<~HTTP.crlf_lines
      HTTP/1.1 204



    HTTP
    assert_equal(expected, response)

  end

  def test_that_server_uses_chunked_encoding_in_http_1_1
    @hook = ->(req) {
      req.respond('Hello, world!')
  }

    # using HTTP 1.0, server should close connection after responding
    write_http_request "GET / HTTP/1.1\r\n\r\n"
    @connection.run

    response = read_client_side
    expected = "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\n\r\nd\r\nHello, world!\r\n0\r\n\r\n"
    assert_equal(expected, response)
  end

  def test_that_server_maintains_connection_if_no_connection_close_header
    @hook = ->(req) {
      req.respond('Hi', {})
    }

    write_http_request "GET / HTTP/1.1\r\nConnection: close\r\n\r\n", false
    res = @connection.serve_request
    assert_equal false, res

    response = read_client_side
    assert_equal("HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\n\r\n2\r\nHi\r\n0\r\n\r\n", response)

    write_http_request "GET / HTTP/1.1\r\n\r\n", false
    res = @connection.serve_request
    assert_equal true, res

    response = read_client_side
    expected = "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\n\r\n2\r\nHi\r\n0\r\n\r\n"
    assert_equal(expected, response)
  end

  def test_pipelining_client
    @hook = ->(req) {
      if req.headers['foo'] == 'bar'
        req.respond('Hello, foobar!', {})
      else
        req.respond('Hello, world!', {})
      end

    }

    write_http_request "GET / HTTP/1.1\r\n\r\nGET / HTTP/1.1\r\nFoo: bar\r\n\r\n"
    @connection.run
    response = read_client_side

    expected = "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\n\r\nd\r\nHello, world!\r\n0\r\n\r\n" +
               "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\n\r\ne\r\nHello, foobar!\r\n0\r\n\r\n"
    assert_equal(expected, response)
  end

  def test_body_chunks
    chunks = []
    request = nil

    @hook = ->(req) {
      request = req
      req.send_headers
      req.each_chunk do |c|
        chunks << c
        req << c.upcase
      end
      req.finish
    }

    msg = "POST / HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n6\r\nfoobar\r\n"
    write_http_request msg, false
    @machine.spin { @connection.serve_request rescue nil }
    @machine.sleep(0.01)

    assert request
    assert_equal %w[foobar], chunks
    assert !request.complete?

    write_http_request "6\r\nbazbud\r\n", false
    @machine.sleep(0.01)
    assert_equal %w[foobar bazbud], chunks
    assert !request.complete?

    write_http_request "0\r\n\r\n"
    @machine.sleep(0.01)
    assert_equal %w[foobar bazbud], chunks
    assert request.complete?

    @machine.sleep(0.01)
    response = read_client_side

    expected = "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\n\r\n6\r\nFOOBAR\r\n6\r\nBAZBUD\r\n0\r\n\r\n"
    assert_equal(expected, response)
  end

  def test_upgrade
    done = nil

    @hook = ->(req) do
      return if req.upgrade_protocol != 'echo'

      req.upgrade(:echo) do |stream, fd|
        @machine.sleep(0.01)
        buf = +''
        while true
          buf = stream.read(0)
          break if !buf

          res = @machine.send(fd, buf, buf.bytesize, 0)
        end
        req.adapter.close
        done = true
      end
    rescue Exception => e
      p e
      p e.backtrace.join("\n")
    end

    msg = "GET / HTTP/1.1\r\nUpgrade: echo\r\nConnection: upgrade\r\n\r\n"
    write_http_request(msg, false)
    @machine.spin { @connection.serve_request rescue nil }
    @machine.sleep(0.01)

    response = read_client_side
    expected = "HTTP/1.1 101\r\nContent-Length: 0\r\nUpgrade: echo\r\nConnection: upgrade\r\n\r\n"
    assert_equal(expected, response)

    assert !done

    write_client_side 'foo'
    assert_equal 'foo', read_client_side

    write_client_side 'bar'
    assert_equal 'bar', read_client_side

    @machine.close(@c_fd)
    assert !done

    @machine.sleep(0.01)
    assert done
  end

  def test_big_download
    chunk_size = 1000
    chunk_count = 1000
    chunk = '*' * chunk_size

    @hook = ->(req) do
      req.send_headers
      chunk_count.times do |i|
        req << chunk
        @machine.snooze
      end
      req.finish
      @machine.close(@s_fd)
    rescue Exception => e
      p e
      p e.backtrace.join("\n")
    end

    response = +''
    count = 0

    write_client_side("GET / HTTP/1.1\r\n\r\n")
    @machine.spin do
      @connection.serve_request
    rescue => e
      p e
      p e.backtrace
    end

    while (data = read_client_side(chunk_size))
      response << data
      count += 1
      @machine.snooze
      break if data[-7..-1] == "\r\n0\r\n\r\n"
    end

    chunks = "#{chunk_size.to_s(16)}\r\n#{'*' * chunk_size}\r\n" * chunk_count
    expected = "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\n\r\n#{chunks}0\r\n\r\n"

    assert_equal expected, response
    assert count >= chunk_count
  end

  def test_static_file_serving
    fn = "/tmp/syntropy-#{rand(1000)}"
    IO.write(fn, 'foobar')

    @hook = ->(req) do
      req.respond_with_static_file(fn, nil, nil, nil)
    rescue => e
      p e
      p e.backtrace
    end

    response = +''
    count = 0

    write_client_side("GET / HTTP/1.1\r\n\r\n")
    @machine.spin do
      @connection.serve_request
    rescue => e
      p e
      p e.backtrace
    end

    while (data = read_client_side(65536))
      response << data
      count += 1
      @machine.snooze
      break if data[-7..-1] == "\r\n0\r\n\r\n"
    end

    content = IO.read(fn)
    file_size = content.bytesize
    expected = "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\n\r\n#{file_size.to_s(16)}\r\n#{content}\r\n0\r\n\r\n"

    assert_equal expected, response
  end

  def test_static_file_serving_big
    fn = "/tmp/syntropy-#{rand(1000)}"
    IO.write(fn, 'foobar')

    @hook = ->(req) do
      req.respond_with_static_file(fn, nil, nil, { max_len: 3 })
      req.adapter.close
    end

    response = +''
    count = 0

    write_client_side("GET / HTTP/1.1\r\n\r\n")
    @machine.spin { @connection.serve_request }

    while (data = read_client_side(65536))
      response << data
      count += 1
      @machine.snooze
    end

    expected = "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\n\r\n3\r\nfoo\r\n3\r\nbar\r\n0\r\n\r\n"
    assert_equal expected, response
  end

  def test_connection_server_headers
    @env[:server_headers] = "Server: Syntropy\r\n"

    @hook = ->(req) do
      req.respond('foo')
    end

    write_client_side("GET / HTTP/1.1\r\n\r\n")
    @connection.serve_request
    response = read_client_side(65536)
    expected = "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\nServer: Syntropy\r\n\r\n3\r\nfoo\r\n0\r\n\r\n"
    assert_equal expected, response

    @env[:server_headers] = "Server: TP3\r\n"

    write_client_side("GET / HTTP/1.1\r\n\r\n")
    @connection.serve_request
    response = read_client_side(65536)
    expected = "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\nServer: TP3\r\n\r\n3\r\nfoo\r\n0\r\n\r\n"
    assert_equal expected, response
  end

  def test_set_response_headers_1
    @hook = ->(req) {
      req.set_response_headers("Set-Cookie" => 'foo=bar')
      req.respond('foo')
    }

    write_client_side("GET / HTTP/1.1\r\n\r\n")
    @connection.serve_request
    response = read_client_side(65536)
    expected = "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\nSet-Cookie: foo=bar\r\n\r\n3\r\nfoo\r\n0\r\n\r\n"
    assert_equal expected, response

    @hook = ->(req) {
      req.set_response_headers("Set-Cookie" => 'foo=bar')
      req.respond('foo', 'Content-Type' => 'text/plain')
    }

    write_client_side("GET / HTTP/1.1\r\n\r\n")
    @connection.serve_request
    response = read_client_side(65536)
    expected = "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\nSet-Cookie: foo=bar\r\nContent-Type: text/plain\r\n\r\n3\r\nfoo\r\n0\r\n\r\n"
    assert_equal expected, response
  end

  def test_set_response_headers_2
    @hook = ->(req) {
      req.set_response_headers("Set-Cookie" => 'foo=bar')
      req.set_response_headers("Foo" => 'bar')
      req.respond('foo', 'Content-Type' => 'text/plain')
    }

    write_client_side("GET / HTTP/1.1\r\n\r\n")
    @connection.serve_request
    response = read_client_side(65536)
    expected = "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\nSet-Cookie: foo=bar\r\nFoo: bar\r\nContent-Type: text/plain\r\n\r\n3\r\nfoo\r\n0\r\n\r\n"
    assert_equal expected, response
  end

  def test_set_cookie_single
    @hook = ->(req) {
      req.set_cookie('foo=bar; HttpOnly')
      req.respond('foo')
    }

    write_client_side("GET / HTTP/1.1\r\n\r\n")
    @connection.serve_request
    response = read_client_side(65536)
    expected = "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\nSet-Cookie: foo=bar; HttpOnly\r\n\r\n3\r\nfoo\r\n0\r\n\r\n"
    assert_equal expected, response

  end

  def test_set_cookie_multi1
    @hook = ->(req) {
      req.set_cookie('foo=bar; HttpOnly', 'bar=baz')
      req.respond('foo')
    }

    write_client_side("GET / HTTP/1.1\r\n\r\n")
    @connection.serve_request
    response = read_client_side(65536)
    expected = "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\nSet-Cookie: foo=bar; HttpOnly\r\nSet-Cookie: bar=baz\r\n\r\n3\r\nfoo\r\n0\r\n\r\n"
    assert_equal expected, response

  end

  def test_set_cookie_multi2
    @hook = ->(req) {
      req.set_cookie('a=1', 'b=2')
      req.set_cookie('c=3')
      req.set_cookie('d=4', 'e=5')
      req.respond('foo')
    }

    write_client_side("GET / HTTP/1.1\r\n\r\n")
    @connection.serve_request
    response = read_client_side(65536)
    expected = "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\nSet-Cookie: a=1\r\nSet-Cookie: b=2\r\nSet-Cookie: c=3\r\nSet-Cookie: d=4\r\nSet-Cookie: e=5\r\n\r\n3\r\nfoo\r\n0\r\n\r\n"
    assert_equal expected, response

  end
end
