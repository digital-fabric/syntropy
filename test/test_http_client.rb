# frozen_string_literal: true

require_relative './helper'
require 'json'

class HTTPClientTest < Minitest::Test
  def setup
    @machine = UM.new
    @handler = ->(req) { req.respond_json(req.headers) }

    @port = 10000 + rand(30000)
    @env = { bind: "127.0.0.1:#{@port}" }
    @server = Syntropy::HTTP::Server.new(@machine, @env) { @app&.call(it) }
    @server_fiber = @machine.spin { @server.run }

    # let server spin and listen to incoming connections
    @machine.sleep(0.01)

    @client = Syntropy::HTTP::Client.new(@machine)
  end

  def teardown
    @machine.schedule(@server_fiber, UM::Terminate.new)
    @machine.join(@server_fiber)
  end

  def test_get
    @app = ->(req) { req.respond('foo') }
    headers, body = @client.get("http://localhost:#{@port}")

    assert_kind_of Hash, headers
    assert_equal Syntropy::HTTP::OK, headers[':status']

    assert_kind_of String, body
    assert_equal 'foo', body
  end

  def test_get_with_block
    @app = ->(req) { req.respond('foo') }
    headers = body = nil
    @client.get("http://localhost:#{@port}") { |h, c|
      headers = h
      body = c.get_response_body(headers)
    }

    assert_kind_of Hash, headers
    assert_equal Syntropy::HTTP::OK, headers[':status']

    assert_kind_of String, body
    assert_equal 'foo', body
  end
end
