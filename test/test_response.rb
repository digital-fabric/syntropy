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
