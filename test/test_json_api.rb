# frozen_string_literal: true

require_relative 'helper'

class JSONAPITest < Minitest::Test
  HTTP = Syntropy::HTTP

  class TestAPI < Syntropy::JSONAPI
    def foo(req)
      @value
    end

    def bar!(req)
      @value = req.query['v']
      true
    end
  end

  def setup
    @app = TestAPI.new({})
  end

  def test_json_api
    req = mock_req(':method' => 'GET', ':path' => '/')
    @app.call(req)
    assert_equal HTTP::BAD_REQUEST, req.response_status

    req = mock_req(':method' => 'GET', ':path' => '/?q=foo')
    @app.call(req)
    assert_equal HTTP::OK, req.response_status
    assert_equal({ 'status' => 'OK', 'response' => nil }, req.response_json)

    req = mock_req(':method' => 'POST', ':path' => '/?q=foo')
    @app.call(req)
    assert_equal HTTP::METHOD_NOT_ALLOWED, req.response_status


    req = mock_req(':method' => 'POST', ':path' => '/?q=bar&v=foo')
    @app.call(req)
    assert_equal HTTP::OK, req.response_status
    assert_equal({ 'status' => 'OK', 'response' => true }, req.response_json)

    req = mock_req(':method' => 'GET', ':path' => '/?q=bar&v=foo')
    @app.call(req)
    assert_equal HTTP::METHOD_NOT_ALLOWED, req.response_status

    req = mock_req(':method' => 'GET', ':path' => '/?q=foo')
    @app.call(req)
    assert_equal HTTP::OK, req.response_status
    assert_equal({ 'status' => 'OK', 'response' => 'foo' }, req.response_json)

    req = mock_req(':method' => 'GET', ':path' => '/?q=foo')
    @app.call(req)
    assert_equal HTTP::OK, req.response_status
    assert_equal({ 'status' => 'OK', 'response' => 'foo' }, req.response_json)

    req = mock_req(':method' => 'GET', ':path' => '/?q=xxx')
    @app.call(req)
    assert_equal HTTP::NOT_FOUND, req.response_status
  end
end
