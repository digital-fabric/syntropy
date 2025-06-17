# frozen_string_literal: true

require_relative 'helper'

class RPCAPITest < Minitest::Test
  class TestAPI < Syntropy::RPCAPI
    def get(ctx)
      @value
    end

    def set!(ctx)
      @value = ctx.params[:v]
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

  def test_req_harness
    req = mock_req(':method' => 'GET', ':path' => '/foo')
    ctx = Syntropy::Context.new(req)
    ret = @app.call(ctx)
    assert_equal Qeweney::Status::NOT_FOUND, req.response_status
  end
end
