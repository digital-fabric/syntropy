# frozen_string_literal: true

require_relative 'helper'

class ContextTest < Minitest::Test
  def setup
    @req = mock_req(':method' => 'GET', ':path' => '/foo?q=foo&x=bar&y=123&z1=t&z2=f')
    @ctx = Syntropy::Context.new(@req)
  end

  def test_request
    assert_equal @req, @ctx.request
  end

  VE = Syntropy::ValidationError

  def test_validate_param
    assert_nil @ctx.validate_param(:azerty, nil)
    assert_equal 'foo', @ctx.validate_param(:q)
    assert_equal 'foo', @ctx.validate_param(:q, String)
    assert_equal 'foo', @ctx.validate_param(:q, [String, nil])
    assert_nil @ctx.validate_param(:r, [String, nil])

    assert_equal 123, @ctx.validate_param(:y, Integer)
    assert_equal 123, @ctx.validate_param(:y, Integer, 120..125)
    assert_equal 123.0, @ctx.validate_param(:y, Float)

    assert_equal true, @ctx.validate_param(:z1, :bool)
    assert_equal false, @ctx.validate_param(:z2, :bool)

    assert_raises(VE) { @ctx.validate_param(:azerty, String) }
    assert_raises(VE) { @ctx.validate_param(:q, Integer) }
    assert_raises(VE) { @ctx.validate_param(:q, Float) }
    assert_raises(VE) { @ctx.validate_param(:q, nil) }
    
    assert_raises(VE) { @ctx.validate_param(:y, Integer, 1..100) }

    assert_raises(VE) { @ctx.validate_param(:y, :bool) }
  end
end
