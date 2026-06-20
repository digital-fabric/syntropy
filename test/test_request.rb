# frozen_string_literal: true

require_relative 'helper'

class RequestInfoTest < Minitest::Test
  def test_uri
    r = Syntropy::MockAdapter.mock(':path' => '/test/path')
    assert_equal '/test/path', r.path
    assert_equal({}, r.query)

    r = Syntropy::MockAdapter.mock(':path' => '/test/path?a=1&b=2&c=3%2f4')
    assert_equal '/test/path', r.path
    assert_equal({ 'a' => '1', 'b' => '2', 'c' => '3/4' }, r.query)
  end

  def test_query
    r = Syntropy::MockAdapter.mock(':path' => '/GponForm/diag_Form?images/')
    assert_equal '/GponForm/diag_Form', r.path
    assert_equal({ 'images/' => true }, r.query)

    r = Syntropy::MockAdapter.mock(':path' => '/?a=1&b=2')
    assert_equal '/', r.path
    assert_equal({ 'a' => '1', 'b' => '2'}, r.query)

    r = Syntropy::MockAdapter.mock(':path' => '/?l=a&t=&x=42')
    assert_equal({ 'l' => 'a', 't' => '', 'x' => '42'}, r.query)
  end

  def test_host
    r = Syntropy::MockAdapter.mock(':path' => '/')
    assert_nil r.host
    assert_nil r.authority

    r = Syntropy::MockAdapter.mock('host' => 'my.example.com')
    assert_equal 'my.example.com', r.host
    assert_equal 'my.example.com', r.authority

    r = Syntropy::MockAdapter.mock(':authority' => 'my.foo.com')
    assert_equal 'my.foo.com', r.host
    assert_equal 'my.foo.com', r.authority
  end

  def test_full_uri
    r = Syntropy::MockAdapter.mock(
      ':scheme' => 'https',
      'host' => 'foo.bar',
      ':path' => '/hey?a=b&c=d'
    )

    assert_equal 'https://foo.bar/hey?a=b&c=d', r.full_uri
  end

  def test_cookies
    r = Syntropy::MockAdapter.mock

    assert_equal({}, r.cookies)

    r = Syntropy::MockAdapter.mock(
      'cookie' => 'uaid=a%2Fb; lastLocus=settings; signin_ref=/'
    )

    assert_equal({
      'uaid' => 'a/b',
      'lastLocus' => 'settings',
      'signin_ref' => '/'
    }, r.cookies)
  end

  def test_content_type
    r = Syntropy::MockAdapter.mock(
      ':scheme' => 'https',
      'host' => 'foo.bar',
      ':path' => '/hey?a=b&c=d',
      'content-type' => 'text/plain'
    )
    assert_equal 'text/plain', r.content_type

    r = Syntropy::MockAdapter.mock(
      ':scheme' => 'https',
      'host' => 'foo.bar',
      ':path' => '/hey?a=b&c=d',
      'content-type' => 'text/plain; charset=utf-8'
    )
    assert_equal 'text/plain', r.content_type

    r = Syntropy::MockAdapter.mock(
      ':scheme' => 'https',
      'host' => 'foo.bar',
      ':path' => '/hey?a=b&c=d',
      'content-type' => 'text/plain ; charset=utf-8'
    )
    assert_equal 'text/plain', r.content_type
  end

  def test_rewrite!
    r = Syntropy::MockAdapter.mock(
      ':scheme' => 'https',
      'host' => 'foo.bar',
      ':path' => '/hey/ho?a=b&c=d'
    )

    assert_equal '/hey/ho', r.path
    assert_equal URI.parse('/hey/ho?a=b&c=d'), r.uri
    assert_equal 'https://foo.bar/hey/ho?a=b&c=d', r.full_uri

    r.rewrite!('/hhh', '/')
    assert_equal '/hey/ho', r.path
    assert_equal URI.parse('/hey/ho?a=b&c=d'), r.uri
    assert_equal 'https://foo.bar/hey/ho?a=b&c=d', r.full_uri

    r.rewrite!('/hey', '/')
    assert_equal '/ho', r.path
    assert_equal URI.parse('/ho?a=b&c=d'), r.uri
    assert_equal 'https://foo.bar/ho?a=b&c=d', r.full_uri
  end

  def test_rel
    r = Syntropy::MockAdapter.mock(
      ':path' => '/posts/42'
    )
    assert_equal '/posts', r.rel('..')
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

    assert_equal 'foo', @req.validate('foo', String, /.+/)
    assert_raises(VE) { @req.validate('', String, /.+/) }

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

  def test_validate_content_type
    @req = mock_req(':method' => 'POST', ':path' => '/foo')

    assert_raises(Syntropy::InvalidRequestContentTypeError) {
      @req.validate_content_type('application/json')
    }

    @req = mock_req(':method' => 'POST', ':path' => '/foo', 'content-type' => 'application/json')
    assert_equal 'application/json', @req.validate_content_type(
      'application/json', 'text/plain'
    )

    @req = mock_req(':method' => 'POST', ':path' => '/foo', 'content-type' => 'text/html; charset=utf-8')
    assert_equal 'text/html', @req.validate_content_type(
      'text/plain', 'text/html'
    )

    @req = mock_req(':method' => 'POST', ':path' => '/foo', 'content-type' => 'text/html ; charset=utf-8')
    assert_equal 'text/html', @req.validate_content_type(
      'text/plain', 'text/html'
    )
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
