# frozen_string_literal: true

require_relative 'helper'

class RequestInfoTest < Minitest::Test
  def test_uri
    r = Syntropy::MockAdapter.mock(':path' => '/test/path')
    assert_equal '/test/path', r.path
    assert_equal({}, r.query)

    r = Syntropy::MockAdapter.mock(':path' => '/test/path?a=1&b=2&c=3%2f4')
    assert_equal '/test/path', r.path
    assert_equal({ a: '1', b: '2', c: '3/4' }, r.query)
  end

  def test_query
    r = Syntropy::MockAdapter.mock(':path' => '/GponForm/diag_Form?images/')
    assert_equal '/GponForm/diag_Form', r.path
    assert_equal({:'images/' => true}, r.query)

    r = Syntropy::MockAdapter.mock(':path' => '/?a=1&b=2')
    assert_equal '/', r.path
    assert_equal({a: '1', b: '2'}, r.query)

    r = Syntropy::MockAdapter.mock(':path' => '/?l=a&t=&x=42')
    assert_equal({l: 'a', t: '', x: '42'}, r.query)
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
end
