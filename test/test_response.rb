# frozen_string_literal: true

require_relative 'helper'

class RedirectTest < Minitest::Test
  def test_redirect
    r = Syntropy::MockAdapter.mock
    r.redirect('/foo')

    assert_equal [
      [:respond, r, nil, {":status"=>302, "Location"=>"/foo"}]
    ], r.adapter.calls
  end

  def test_redirect_wirth_status
    r = Syntropy::MockAdapter.mock
    r.redirect('/bar', Syntropy::HTTP::MOVED_PERMANENTLY)

    assert_equal [
      [:respond, r, nil, {":status"=>301, "Location"=>"/bar"}]
    ], r.adapter.calls
  end

  def test_redirect_relative_path
    r = Syntropy::MockAdapter.mock(':path' => '/foo')
    r.redirect('./bar')
    assert_equal '/foo/bar', r.response_headers['Location']

    r = Syntropy::MockAdapter.mock(':path' => '/foo/bar')
    r.redirect('./baz')
    assert_equal '/foo/bar/baz', r.response_headers['Location']

    r = Syntropy::MockAdapter.mock(':path' => '/foo/bar')
    r.redirect('../baz')
    assert_equal '/foo/baz', r.response_headers['Location']

    r = Syntropy::MockAdapter.mock(':path' => '/')
    r.redirect('./baz')
    assert_equal '/baz', r.response_headers['Location']

    r = Syntropy::MockAdapter.mock(':path' => '/')
    r.redirect('../baz')
    assert_equal '/baz', r.response_headers['Location']

    r = Syntropy::MockAdapter.mock(':path' => '/posts')
    r.redirect('./42')
    assert_equal '/posts/42', r.response_headers['Location']

    r = Syntropy::MockAdapter.mock(':path' => '/posts/42')
    r.redirect('..')
    assert_equal '/posts', r.response_headers['Location']
  end
end

class UpgradeTest < Minitest::Test
  def test_upgrade
    r = Syntropy::MockAdapter.mock
    r.upgrade('df')

    assert_equal [
      [
        :respond,
        r,
        nil,
        {
          ':status' => 101,
          'Upgrade' => 'df',
          'Connection' => 'upgrade'
        }
      ],
      [
        :with_stream
      ]
    ], r.adapter.calls


    r = Syntropy::MockAdapter.mock
    r.upgrade('df', { 'foo' => 'bar' })

    assert_equal [
      [
        :respond,
        r,
        nil,
        {
          ':status' => 101,
          'Upgrade' => 'df',
          'Connection' => 'upgrade',
          'foo' => 'bar'
        }
      ],
      [
        :with_stream
      ]
    ], r.adapter.calls
  end

  def test_websocket_upgrade
    r = Syntropy::MockAdapter.mock(
      'connection' => 'upgrade',
      'upgrade' => 'websocket',
      'sec-websocket-version' => '23',
      'sec-websocket-key' => 'abcdefghij'
    )

    assert_equal 'websocket', r.upgrade_protocol

    r.upgrade_to_websocket('foo' => 'baz')
    accept = Digest::SHA1.base64digest('abcdefghij258EAFA5-E914-47DA-95CA-C5AB0DC85B11')

    assert_equal [
      [:respond, r, nil, {
        ':status' => 101,
        'Upgrade' => 'websocket',
        'Connection' => 'upgrade',
        'foo' => 'baz',
        'Sec-WebSocket-Accept' => accept
      }],
      [:with_stream],
      [:websocket_connection, r]
    ], r.adapter.calls
  end
end

class SSETest < Minitest::Test
  def test_respond_sse_block_empty
    r = Syntropy::MockAdapter.mock
    r.respond_sse {}

    assert_equal [
      [:send_headers, r, { 'Content-Type' => 'text/event-stream'}, {empty_response: false}],
      [:finish, r]
    ], r.adapter.calls
  end

  def test_respond_sse_block
    r = Syntropy::MockAdapter.mock
    r.respond_sse {
      r.send_event('foo')
      r.send_event('bar', 'baz')
      r.send_event('foo' => 'bar')
      r.send_event(
        { 'bar' => 'baz' },
        { 'baz' => 'foo' },
      )
    }

    assert_equal [
      [:send_headers, r, { 'Content-Type' => 'text/event-stream'}, {empty_response: false}],
      [:send_chunk, r, "data: foo\n\n", { done: false }],
      [:send_chunk, r, "data: bar\n\n", { done: false }],
      [:send_chunk, r, "data: baz\n\n", { done: false }],
      [:send_chunk, r, "event: foo\ndata: bar\n\n", { done: false }],
      [:send_chunk, r, "event: bar\ndata: baz\n\n", { done: false }],
      [:send_chunk, r, "event: baz\ndata: foo\n\n", { done: false }],
      [:finish, r]
    ], r.adapter.calls
  end

  def test_respond_sse_no_block_no_events
    r = Syntropy::MockAdapter.mock
    r.respond_sse()

    assert_equal [
      [:send_headers, r, { 'Content-Type' => 'text/event-stream'}, {empty_response: false}],
      [:finish, r]
    ], r.adapter.calls
  end

  def test_respond_sse_no_block_single_arg
    r = Syntropy::MockAdapter.mock
    r.respond_sse('foo')

    assert_equal [
      [:send_headers, r, { 'Content-Type' => 'text/event-stream'}, {empty_response: false}],
      [:send_chunk, r, "data: foo\n\n", { done: false }],
      [:finish, r]
    ], r.adapter.calls
  end

  def test_respond_sse_no_block_multi_args
    r = Syntropy::MockAdapter.mock
    r.respond_sse('foo', 'bar')

    assert_equal [
      [:send_headers, r, { 'Content-Type' => 'text/event-stream'}, {empty_response: false}],
      [:send_chunk, r, "data: foo\n\n", { done: false }],
      [:send_chunk, r, "data: bar\n\n", { done: false }],
      [:finish, r]
    ], r.adapter.calls
  end

  def test_respond_sse_no_block_single_hash
    r = Syntropy::MockAdapter.mock
    r.respond_sse('foo' => 'bar')

    assert_equal [
      [:send_headers, r, { 'Content-Type' => 'text/event-stream'}, {empty_response: false}],
      [:send_chunk, r, "event: foo\ndata: bar\n\n", { done: false }],
      [:finish, r]
    ], r.adapter.calls
  end

  def test_respond_sse_no_block_multi_hashes
    r = Syntropy::MockAdapter.mock
    r.respond_sse({ 'foo' => 'bar' }, { 'bar' => 'baz', 'baz' => 'foo' })

    assert_equal [
      [:send_headers, r, { 'Content-Type' => 'text/event-stream'}, {empty_response: false}],
      [:send_chunk, r, "event: foo\ndata: bar\n\n", { done: false }],
      [:send_chunk, r, "event: bar\ndata: baz\n\n", { done: false }],
      [:send_chunk, r, "event: baz\ndata: foo\n\n", { done: false }],
      [:finish, r]
    ], r.adapter.calls
  end

  def test_send_event_multi_data
    r = Syntropy::MockAdapter.mock
    r.respond_sse(['foo', 'bar', 'baz'])

    assert_equal [
      [:send_headers, r, { 'Content-Type' => 'text/event-stream'}, {empty_response: false}],
      [:send_chunk, r, "data: foo\ndata: bar\ndata: baz\n\n", { done: false }],
      [:finish, r]
    ], r.adapter.calls
  end

  def test_send_event_multi_data_hash
    r = Syntropy::MockAdapter.mock
    r.respond_sse('patch' => ['foo', 'bar', 'baz'])

    assert_equal [
      [:send_headers, r, { 'Content-Type' => 'text/event-stream'}, {empty_response: false}],
      [:send_chunk, r, "event: patch\ndata: foo\ndata: bar\ndata: baz\n\n", { done: false }],
      [:finish, r]
    ], r.adapter.calls
  end
end
