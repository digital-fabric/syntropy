# frozen_string_literal: true

require_relative 'helper'
require 'brotli'

class BrotliCompressionTest < Minitest::Test
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

    @app = ->(req) do
      req.auto_compress!
      req.respond('foobar')
    end
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

  def test_brotli_compression_no_accept_encoding
    write_http_request "GET / HTTP/1.1\r\n\r\n"
    response = read_client_side
    expected = "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\n\r\n6\r\nfoobar\r\n0\r\n\r\n"
    assert_equal(expected, response)
  end

  def test_brotli_compression_accept_encoding_gzip
    write_http_request "GET / HTTP/1.1\r\nAccept-Encoding: gzip,zstd\r\n\r\n"
    response = read_client_side
    expected = "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\n\r\n6\r\nfoobar\r\n0\r\n\r\n"
    assert_equal(expected, response)
  end

  def test_brotli_compression_accept_encoding_br
    write_http_request "GET / HTTP/1.1\r\nAccept-Encoding: br\r\n\r\n"
    response = read_client_side
    compressor = Brotli::Compressor.new(quality: 6)
    out = compressor.process('foobar')
    out << compressor.flush
    expected = "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\nContent-Encoding: br\r\n\r\n#{out.bytesize}\r\n#{out}\r\n0\r\n\r\n"
    assert_equal(expected.force_encoding('BINARY'), response.force_encoding('BINARY'))
  end

  def test_brotli_compression_multiple_chunks
    @app = ->(req) do
      req.auto_compress!
      req.send_headers
      req.send_chunk('foobar')
      req.send_chunk('barbaz')
      req.finish
    end

    write_http_request "GET / HTTP/1.1\r\nAccept-Encoding: br\r\n\r\n"
    @machine.sleep(0.1)
    response = read_client_side
    compressor = Brotli::Compressor.new(quality: 6)
    chunk1 = compressor.process('foobar')
    chunk1 << compressor.flush
    chunk2 = compressor.process('barbaz')
    chunk2 << compressor.flush    
    expected = "HTTP/1.1 200\r\nTransfer-Encoding: chunked\r\nContent-Encoding: br\r\n\r\n#{chunk1.bytesize.to_s(16)}\r\n#{chunk1}\r\n#{chunk2.bytesize.to_s(16)}\r\n#{chunk2}\r\n0\r\n\r\n"

    assert_equal(expected.force_encoding('BINARY'), response.force_encoding('BINARY'))
  end
end
