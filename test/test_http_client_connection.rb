# frozen_string_literal: true

require_relative './helper'
require 'json'

class HTTPClientConectionTest < Minitest::Test
  def setup
    @client_fd, @server_fd = UM.socketpair(UM::AF_UNIX, UM::SOCK_STREAM, 0)
    @machine = UM.new
    @handler = ->(req) { req.respond_json(req.headers) }
    @server_connection = Syntropy::HTTP::ServerConnection.new(
      @machine, @server_fd, {}, &->(req) { @handler.(req) }
    )
    @server_fiber = @machine.spin { @server_connection.run }
    @client_connection = Syntropy::HTTP::ClientConnection.new(
      @machine, @client_fd
    )
  end

  def teardown
    @machine.schedule(@server_fiber, UM::Terminate.new)
    @machine.join(@server_fiber)
  end

  def test_req_teapot
    @handler = ->(req) { req.respond(nil, ':status' => Syntropy::HTTP::TEAPOT) }
    headers = @client_connection.req(':method' => 'GET', ':path' => '/')

    assert_kind_of Hash, headers
    assert_equal Syntropy::HTTP::TEAPOT, headers[':status']
  end

  def test_req_with_response_body
    @handler = ->(req) { req.respond('foo') }
    headers = @client_connection.req(':method' => 'GET', ':path' => '/')

    assert_kind_of Hash, headers
    assert_equal Syntropy::HTTP::OK, headers[':status']

    body = @client_connection.get_response_body(headers)
    assert_equal 'foo', body
  end
end
