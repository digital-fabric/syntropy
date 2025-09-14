# frozen_string_literal: true

require_relative 'helper'
require 'digest/sha1'

class CachingTest < Minitest::Test
  Status = Qeweney::Status

  APP_ROOT = File.join(__dir__, 'app')

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

    @tmp_path = '/test/tmp'
    @tmp_fn = File.join(APP_ROOT, 'tmp.rb')

    @env = {
      machine: @machine,
      root_dir: APP_ROOT,
      mount_path: '/test',
      watch_files: 0.05
    }

    @app = Syntropy::App.new(**@env)

    @c_fd, @s_fd = make_socket_pair
    @adapter = TP2::Connection.new(nil, @machine, @s_fd, @env) { @app.(it) }
  end

  def teardown
    @machine.close(@c_fd) rescue nil
    @machine.close(@s_fd) rescue nil
  end

  def write_http_request(msg, shutdown_wr = false)
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

  def test_static_file_caching
    fn = File.join(APP_ROOT, 'assets/style.css')
    stat = @machine.statx(UM::AT_FDCWD, fn, 0, UM::STATX_ALL)
    content = IO.read(fn)
    etag = Digest::SHA1.hexdigest(content)
    last_modified = Time.at(stat[:mtime]).httpdate
    size = stat[:size]

    write_http_request "GET /test/assets/style.css HTTP/1.1\r\n\r\n"
    @adapter.serve_request
    response = read_client_side

    expected = "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\nCache-Control: max-age=3600\r\nEtag: #{etag}\r\nLast-Modified: #{last_modified}\r\nContent-Type: text/css\r\n\r\n#{size.to_s(16)}\r\n#{content}\r\n0\r\n\r\n"
    assert_equal expected, response
  end

  def test_static_file_caching_validate_etag
    fn = File.join(APP_ROOT, 'assets/style.css')
    stat = @machine.statx(UM::AT_FDCWD, fn, 0, UM::STATX_ALL)
    content = IO.read(fn)
    etag = Digest::SHA1.hexdigest(content)
    last_modified = Time.at(stat[:mtime]).httpdate
    size = stat[:size]

    # bad etag
    write_http_request "GET /test/assets/style.css HTTP/1.1\r\nIf-None-Match: foo\r\n\r\n"
    @adapter.serve_request
    response = read_client_side

    expected = "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\nCache-Control: max-age=3600\r\nEtag: #{etag}\r\nLast-Modified: #{last_modified}\r\nContent-Type: text/css\r\n\r\n#{size.to_s(16)}\r\n#{content}\r\n0\r\n\r\n"
    assert_equal expected, response

    # good etag
    @adapter.response_headers.clear
    write_http_request "GET /test/assets/style.css HTTP/1.1\r\nIf-None-Match: #{etag}\r\n\r\n"
    @adapter.serve_request
    response = read_client_side

    expected = "HTTP/1.1 304\r\nContent-Length: 0\r\n\r\n"
    assert_equal expected, response
  end

  def test_static_file_caching_validate_last_modified
    fn = File.join(APP_ROOT, 'assets/style.css')
    stat = @machine.statx(UM::AT_FDCWD, fn, 0, UM::STATX_ALL)
    content = IO.read(fn)
    etag = Digest::SHA1.hexdigest(content)
    last_modified = Time.at(stat[:mtime]).httpdate
    size = stat[:size]

    # bad stamp
    write_http_request "GET /test/assets/style.css HTTP/1.1\r\nIf-Modified-Since: foo\r\n\r\n"
    @adapter.serve_request
    response = read_client_side

    expected = "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\nCache-Control: max-age=3600\r\nEtag: #{etag}\r\nLast-Modified: #{last_modified}\r\nContent-Type: text/css\r\n\r\n#{size.to_s(16)}\r\n#{content}\r\n0\r\n\r\n"
    assert_equal expected, response

    # good etag
    @adapter.response_headers.clear
    write_http_request "GET /test/assets/style.css HTTP/1.1\r\nIf-Modified-Since: #{last_modified}\r\n\r\n"
    @adapter.serve_request
    response = read_client_side

    expected = "HTTP/1.1 304\r\nContent-Length: 0\r\n\r\n"
    assert_equal expected, response
  end
end
