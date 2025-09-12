# frozen_string_literal: true

require_relative 'helper'

class JSONAPITest < Minitest::Test
  class TestAPI < Syntropy::JSONAPI
    def foo(req)
      @value
    end

    def bar!(req)
      @value = req.query[:v]
      true
    end
  end

  def setup
    @app = TestAPI.new({})
  end

  def test_json_api
    req = mock_req(':method' => 'GET', ':path' => '/')
    @app.call(req)
    assert_equal Qeweney::Status::BAD_REQUEST, req.response_status

    req = mock_req(':method' => 'GET', ':path' => '/?q=foo')
    @app.call(req)
    assert_equal Qeweney::Status::OK, req.response_status
    assert_equal({ status: 'OK', response: nil }, req.response_json)

    req = mock_req(':method' => 'POST', ':path' => '/?q=foo')
    @app.call(req)
    assert_equal Qeweney::Status::METHOD_NOT_ALLOWED, req.response_status


    req = mock_req(':method' => 'POST', ':path' => '/?q=bar&v=foo')
    @app.call(req)
    assert_equal Qeweney::Status::OK, req.response_status
    assert_equal({ status: 'OK', response: true }, req.response_json)

    req = mock_req(':method' => 'GET', ':path' => '/?q=bar&v=foo')
    @app.call(req)
    assert_equal Qeweney::Status::METHOD_NOT_ALLOWED, req.response_status

    req = mock_req(':method' => 'GET', ':path' => '/?q=foo')
    @app.call(req)
    assert_equal Qeweney::Status::OK, req.response_status
    assert_equal({ status: 'OK', response: 'foo' }, req.response_json)

    req = mock_req(':method' => 'GET', ':path' => '/?q=foo')
    @app.call(req)
    assert_equal Qeweney::Status::OK, req.response_status
    assert_equal({ status: 'OK', response: 'foo' }, req.response_json)

    req = mock_req(':method' => 'GET', ':path' => '/?q=xxx')
    @app.call(req)
    assert_equal Qeweney::Status::NOT_FOUND, req.response_status
  end
end
