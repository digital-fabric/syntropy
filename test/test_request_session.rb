# frozen_string_literal: true

require_relative 'helper'

class RequestSessionTest < Minitest::Test
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

    @app = ->(req) { req.respond(nil, ':status' => Syntropy::HTTP::INTERNAL_SERVER_ERROR) }
    @env = {}
    @connection = Syntropy::HTTP::ServerConnection.new(@machine, @s_fd, @env) { |req| @app.(req) }
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

  def test_session_kv_access
    current = :something

    @app = ->(req) {
      req.session['foo'] = 'bar'
      current = req.session['foo']
      req.respond(nil)
    }

    write_http_request "GET / HTTP/1.1\r\n\r\n"
    @connection.serve_request

    assert_equal 'bar', current

    response = read_client_side
    data = Base64.strict_encode64(JSON.dump({ 'foo' => 'bar' }))
    assert_equal "HTTP/1.1 204\r\nSet-Cookie: __syntropy_session__=#{data}; Path=/; HttpOnly\r\n\r\n", response
  end

  def test_session_kv_multi
    @app = ->(req) {
      req.session['foo'] = 'bar'
      req.session['bar'] = 'baz'
      req.respond(nil)
    }

    write_http_request "GET / HTTP/1.1\r\n\r\n"
    @connection.serve_request

    response = read_client_side
    data = Base64.strict_encode64(JSON.dump({ 'foo' => 'bar', 'bar' => 'baz' }))
    assert_equal "HTTP/1.1 204\r\nSet-Cookie: __syntropy_session__=#{data}; Path=/; HttpOnly\r\n\r\n", response
  end

  def test_session_kv_sequence
    counter = 0

    @app = ->(req) {
      counter += 1
      case counter
      when 1
        req.session['foo'] = 'bar'
      when 2
        req.session['foo'] = req.session['foo'] + 'baz'
      end
      req.respond(nil)
    }

    write_http_request "GET / HTTP/1.1\r\n\r\n", false
    @connection.serve_request
    response = read_client_side
    data = Base64.strict_encode64(JSON.dump({ 'foo' => 'bar' }))
    assert_equal "HTTP/1.1 204\r\nSet-Cookie: __syntropy_session__=#{data}; Path=/; HttpOnly\r\n\r\n", response

    write_http_request "GET / HTTP/1.1\r\nCookie: __syntropy_session__=#{data}\r\n\r\n"
    @connection.serve_request
    response = read_client_side
    data = Base64.strict_encode64(JSON.dump({ 'foo' => 'barbaz' }))
    assert_equal "HTTP/1.1 204\r\nSet-Cookie: __syntropy_session__=#{data}; Path=/; HttpOnly\r\n\r\n", response
  end

  def test_session_kv_delete
    counter = 0

    @app = ->(req) {
      counter += 1
      case counter
      when 1
        req.session['foo'] = 'bar'
      when 2
        req.session.delete('foo')
      end
      req.respond(nil)
    }

    write_http_request "GET / HTTP/1.1\r\n\r\n", false
    @connection.serve_request
    response = read_client_side
    data = Base64.strict_encode64(JSON.dump({ 'foo' => 'bar' }))
    assert_equal "HTTP/1.1 204\r\nSet-Cookie: __syntropy_session__=#{data}; Path=/; HttpOnly\r\n\r\n", response

    write_http_request "GET / HTTP/1.1\r\nCookie: __syntropy_session__=#{data}\r\n\r\n"
    @connection.serve_request
    response = read_client_side
    assert_equal "HTTP/1.1 204\r\nSet-Cookie: __syntropy_session__=; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Path=/; Max-Age=0; HttpOnly\r\n\r\n", response
  end

  def test_session_discard
    counter = 0

    @app = ->(req) {
      counter += 1
      case counter
      when 1
        req.session['foo'] = 'bar'
      when 2
        req.session.discard
      end
      req.respond(nil)
    }

    write_http_request "GET / HTTP/1.1\r\n\r\n", false
    @connection.serve_request
    response = read_client_side
    data = Base64.strict_encode64(JSON.dump({ 'foo' => 'bar' }))
    assert_equal "HTTP/1.1 204\r\nSet-Cookie: __syntropy_session__=#{data}; Path=/; HttpOnly\r\n\r\n", response

    write_http_request "GET / HTTP/1.1\r\nCookie: __syntropy_session__=#{data}\r\n\r\n"
    @connection.serve_request
    response = read_client_side
    assert_equal "HTTP/1.1 204\r\nSet-Cookie: __syntropy_session__=; Expires=Thu, 01 Jan 1970 00:00:00 GMT; Path=/; Max-Age=0; HttpOnly\r\n\r\n", response
  end

  def test_flash_simple
    counter = 0
    flash_notices = []

    @app = ->(req) do
      counter += 1
      case counter
      when 1
        req.session.flash[:notice] = "Hello flash!"
        flash_notices << req.session.flash[:notice]
      when 2
        flash_notices << req.session.flash[:notice]
      when 3
        flash_notices << req.session.flash[:notice]
      end
      req.respond(nil)
    end

    parse_cookie = ->(response) {
      m = response.match(/Set-Cookie: __syntropy_session__=([^\s;]*)/)
      m && m[1]
    }

    cookie = nil

    3.times {
      request = cookie ? "GET / HTTP/1.1\r\nCookie: __syntropy_session__=#{cookie}\r\n\r\n" : "GET / HTTP/1.1\r\n\r\n"
      write_http_request request, false
      @connection.serve_request
      response = read_client_side
      v = parse_cookie.(response)
      if v
        cookie = v.empty? ? nil : v
      end
    }

    assert_equal [nil, 'Hello flash!', nil], flash_notices
  end

  def test_flash_each
    counter = 0
    flash_content = []

    @app = ->(req) do
      counter += 1
      case counter
      when 1
        req.session.flash[:notice] = "Hello flash!"
        a = []
        req.session.flash.each { |k, v| a << [k, v] }
        flash_content << a
      when 2
        a = []
        req.session.flash.each { |k, v| a << [k, v] }
        flash_content << a
      when 3
        a = []
        req.session.flash.each { |k, v| a << [k, v] }
        flash_content << a
      end
      req.respond(nil)
    end

    parse_cookie = ->(response) {
      m = response.match(/Set-Cookie: __syntropy_session__=([^\s;]*)/)
      m && m[1]
    }

    set_cookies = []
    cookie = nil

    3.times {
      request = cookie ? "GET / HTTP/1.1\r\nCookie: __syntropy_session__=#{cookie}\r\n\r\n" : "GET / HTTP/1.1\r\n\r\n"
      write_http_request request, false
      @connection.serve_request
      response = read_client_side
      v = parse_cookie.(response)
      if v
        cookie = v.empty? ? nil : v
      end
      set_cookies << v ? cookie : nil
    }

    assert_equal [
      [],
      [[:notice, 'Hello flash!']],
      []
    ], flash_content
  end
end
