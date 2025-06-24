# frozen_string_literal: true

require_relative 'helper'

class RPCAPITest < Minitest::Test
  class TestAPI < Syntropy::RPCAPI
    def get(req)
      @value
    end

    def set!(req)
      @value = req.query[:v]
      true
    end
  end

  def setup
    @app = TestAPI.new({})
  end

  def test_rpc_api
    req = mock_req(':method' => 'GET', ':path' => '/')
    @app.call(req)
    assert_equal Qeweney::Status::BAD_REQUEST, req.response_status

    req = mock_req(':method' => 'GET', ':path' => '/?q=get')
    @app.call(req)
    assert_equal Qeweney::Status::OK, req.response_status
    assert_equal({ status: 'OK', response: nil }, req.response_json)

    req = mock_req(':method' => 'POST', ':path' => '/?q=set&v=foo')
    @app.call(req)
    assert_equal Qeweney::Status::OK, req.response_status
    assert_equal({ status: 'OK', response: true }, req.response_json)

    req = mock_req(':method' => 'GET', ':path' => '/?q=get')
    @app.call(req)
    assert_equal Qeweney::Status::OK, req.response_status
    assert_equal({ status: 'OK', response: 'foo' }, req.response_json)
  end
end
