# frozen_string_literal: true

require_relative 'helper'

class RPCAPITest < Minitest::Test
  class TestAPI < Syntropy::RPCAPI
    def get(ctx)
      @value
    end

    def set!(ctx)
      @value = ctx.params[:v]
      true
    end
  end

  def setup
    @app = TestAPI.new('/api/v1')
  end

  def test_kernel_version
    v = UringMachine.kernel_version
    assert_kind_of Integer, v
    assert_in_range 600..700, v
  end

  def test_rpc_api
    req = mock_req(':method' => 'GET', ':path' => '/foo')
    ctx = Syntropy::Context.new(req)
    @app.call(ctx)
    assert_equal Qeweney::Status::BAD_REQUEST, req.response_status

    req = mock_req(':method' => 'GET', ':path' => '/foo?q=get')
    ctx = Syntropy::Context.new(req)
    @app.call(ctx)
    assert_equal Qeweney::Status::OK, req.response_status
    assert_equal({ status: 'OK', response: nil }, req.response_json)

    req = mock_req(':method' => 'POST', ':path' => '/foo?q=set&v=foo')
    ctx = Syntropy::Context.new(req)
    @app.call(ctx)
    assert_equal Qeweney::Status::OK, req.response_status
    assert_equal({ status: 'OK', response: true }, req.response_json)

    req = mock_req(':method' => 'GET', ':path' => '/foo?q=get')
    ctx = Syntropy::Context.new(req)
    @app.call(ctx)
    assert_equal Qeweney::Status::OK, req.response_status
    assert_equal({ status: 'OK', response: 'foo' }, req.response_json)
  end
end
