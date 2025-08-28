# frozen_string_literal: true

require_relative 'helper'

class MethodValidationTest < Minitest::Test
  VE = Syntropy::ValidationError

  def test_validate_http_method
    @req = mock_req(':method' => 'GET', ':path' => '/foo')

    assert_equal 'get', @req.validate_http_method('get', 'head')
    assert_raises(Syntropy::Error) { @req.validate_http_method('post', 'put') }
    assert_raises(Syntropy::Error) { @req.validate_http_method() }
  end

  def test_respond_by_http_method
    @req = mock_req(':method' => 'GET', ':path' => '/foo')

    @req.respond_by_http_method(
      'get' => ['GET foo', {}],
      'post' => ['POST foo', {}]
    )
    assert_equal 'GET foo', @req.response_body

    assert_raises(Syntropy::Error) {
      @req.respond_by_http_method(
        'post' => ['POST foo', {}]
      )
    }
  end
end

class ValidationTest < Minitest::Test
  def setup
    @req = mock_req(':method' => 'GET', ':path' => '/foo?q=foo&x=bar&y=123&z1=t&z2=f')
  end

  VE = Syntropy::ValidationError

  def test_validate_param
    assert_nil @req.validate_param(:azerty, nil)
    assert_equal 'foo', @req.validate_param(:q)
    assert_equal 'foo', @req.validate_param(:q, String)
    assert_equal 'foo', @req.validate_param(:q, [String, nil])
    assert_nil @req.validate_param(:r, [String, nil])

    assert_equal 123, @req.validate_param(:y, Integer)
    assert_equal 123, @req.validate_param(:y, Integer, 120..125)
    assert_equal 123.0, @req.validate_param(:y, Float)

    assert_equal true, @req.validate_param(:z1, :bool)
    assert_equal false, @req.validate_param(:z2, :bool)

    assert_raises(VE) { @req.validate_param(:azerty, String) }
    assert_raises(VE) { @req.validate_param(:q, Integer) }
    assert_raises(VE) { @req.validate_param(:q, Float) }
    assert_raises(VE) { @req.validate_param(:q, nil) }

    assert_raises(VE) { @req.validate_param(:y, Integer, 1..100) }

    assert_raises(VE) { @req.validate_param(:y, :bool) }
  end

  def test_validate
    assert_equal 'foo', @req.validate('foo')
    assert_raises(VE) { @req.validate(nil) }

    assert_nil          @req.validate(nil, nil)
    assert_raises(VE) { @req.validate(1, nil) }

    assert_equal 'foo', @req.validate('foo', String)
    assert_equal 'foo', @req.validate('foo', [String, nil])
    assert_nil          @req.validate(nil, [String, nil])

    assert_equal 123,   @req.validate('123', Integer)
    assert_raises(VE) { @req.validate('a123', Integer) }
    assert_equal 123,   @req.validate('123', Integer, 120..125)
    assert_raises(VE) { @req.validate('223', Integer, 120..125) }
    assert_equal 123.0, @req.validate('123.0', Float)
    assert_equal 123.0, @req.validate('123', Float)
    assert_raises(VE) { @req.validate('123.0', Integer) }
    assert_raises(VE) { @req.validate('x123.0', Float) }
    assert_equal 123.0,   @req.validate('123.0', Float, 120..125)
    assert_raises(VE) { @req.validate('223', Float, 120..125) }

    assert_equal true,  @req.validate('t', :bool)
    assert_equal false, @req.validate('f', :bool)
    assert_equal true,  @req.validate('1', :bool)
    assert_equal false, @req.validate('0', :bool)
    assert_raises(VE) { @req.validate('foo', :bool) }
    assert_raises(VE) { @req.validate(nil, :bool) }
  end
end

class FormDataTest < Minitest::Test
  def test_get_form_data_multipart
    @req = mock_req({
      ':method' => 'POST',
      ':path' => '/',
      'content-type' => 'multipart/form-data; boundary=87654321'
    }, nil)
    assert_raises(Syntropy::Error) { @req.get_form_data }

    @req = mock_req({
      ':method' => 'POST',
      ':path' => '/',
      'content-type' => 'multipart/form-data; boundary=87654321'
    }, "foobar")
    assert_raises(Syntropy::Error) { @req.get_form_data }

    body = <<~EOF
      --87654321
      Content-Disposition: form-data; name="foo"

      barbaz
      --87654321
      Content-Disposition: form-data; name="bar"

      BARBAR
      --87654321--
    EOF

    @req = mock_req({
      ':method' => 'POST',
      ':path' => '/',
      'content-type' => 'multipart/form-data; boundary=87654321'
    }, body.gsub("\n", "\r\n"))

    data = @req.get_form_data
    assert_equal ['bar', 'foo'], data.keys.sort

    assert_equal 'barbaz', data['foo']
    assert_equal 'BARBAR', data['bar']
  end

  def test_get_form_data_urlencoded
    @req = mock_req({
      ':method' => 'POST',
      ':path' => '/',
      'content-type' => 'application/x-www-form-urlencoded'
    }, nil)
    assert_raises(Syntropy::Error) { @req.get_form_data }

    @req = mock_req({
      ':method' => 'POST',
      ':path' => '/',
      'content-type' => 'application/x-www-form-urlencoded'
    }, 'abc')
    data = @req.get_form_data
    assert_equal ['abc'], data.keys
    assert_equal true, data['abc']

    @req = mock_req({
      ':method' => 'POST',
      ':path' => '/',
      'content-type' => 'application/x-www-form-urlencoded'
    }, 'foo=bar&bar=baz')
    data = @req.get_form_data
    assert_equal ['bar', 'foo'], data.keys.sort
    assert_equal 'bar', data['foo']
    assert_equal 'baz', data['bar']
  end
end
