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
end

class StaticFileResponeTest < Minitest::Test
  def setup
    @path = File.join(__dir__, 'helper.rb')
    @stat = File.stat(@path)

    @etag = Syntropy::StaticFileCaching.file_stat_to_etag(@stat)
    @last_modified = Syntropy::StaticFileCaching.file_stat_to_last_modified(@stat)
    @content = IO.read(@path)
  end

  def test_serve_file_non_existent
    r = Syntropy::MockAdapter.mock
    r.serve_file('foo.rb', base_path: __dir__)
    assert_equal [
      [:respond, r, nil, { ':status' => Syntropy::HTTP::NOT_FOUND }]
    ], r.adapter.calls
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
