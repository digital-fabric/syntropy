# frozen_string_literal: true

require_relative 'helper'

class MockAdapterTest < Minitest::Test
  def test_mock_adapter
    adapter = Syntropy::MockAdapter.new(nil)
    req = Syntropy::Request.new({ ':path' => '/foo' }, adapter)
    req.respond('bar', 'Content-Type' => 'baz')

    assert_equal 'bar', adapter.response_body
    assert_equal({'Content-Type' => 'baz'}, adapter.response_headers)
  end

  def test_mock_adapter_with_body
    adapter = Syntropy::MockAdapter.new('barbaz')
    req = Syntropy::Request.new({ ':path' => '/foo' }, adapter)
    assert_equal false, req.complete?

    body = req.read
    assert_equal 'barbaz', body
    assert_equal true, req.complete?
  end

  def test_mock_adapter_with_chunked_body
    adapter = Syntropy::MockAdapter.new(['bar', 'baz'])
    req = Syntropy::Request.new({ ':path' => '/foo' }, adapter)
    assert_equal false, req.complete?

    chunk = req.next_chunk
    assert_equal 'bar', chunk
    assert_equal false, req.complete?

    chunk = req.next_chunk
    assert_equal 'baz', chunk
    assert_equal true, req.complete?
  end

  def test_mock_adapter_each_chunk
    chunks = []
    adapter = Syntropy::MockAdapter.new(['bar', 'baz'])
    req = Syntropy::Request.new({ ':path' => '/foo' }, adapter)
    assert_equal false, req.complete?

    req.each_chunk { chunks << _1 }
    assert_equal ['bar', 'baz'], chunks
    assert_equal true, req.complete?
  end

  def test_set_response_headers
    adapter = Syntropy::MockAdapter.new(nil)
    req = Syntropy::Request.new({ ':path' => '/foo' }, adapter)
    adapter.set_response_headers('Foo' => 'bar')
    req.respond('hi', 'Bar' => 'baz')

    assert_equal 'hi', adapter.response_body
    assert_equal({'Foo' => 'bar', 'Bar' => 'baz'}, adapter.response_headers)
  end
end
