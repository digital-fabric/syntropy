# frozen_string_literal: true

require_relative './helper'

class HTTPProtocolTest < Minitest::Test
  def setup
    @machine = UM.new
    @r, @w = UM.pipe
    @io = @machine.io(@r)
  end

  def teardown
    @machine.close(@r) rescue nil
    @machine.close(@w) rescue nil
    @io = nil
    @machine = nil
  end

  def write(str)
    @machine.write(@w, str)
  end
end

class HTTPProtocolRequestTest < HTTPProtocolTest
  def test_http_request_headers_basic
    write("GET /foo HTTP/1.1\r\nHost: bar.baz\r\n\r\n")
    h = @io.http_read_request_headers
    assert_equal({
      ':method'   => 'get',
      ':path'     => '/foo',
      'host'    => 'bar.baz'
    }, h)
  end

  def test_http_request_headers_bad_http_method
    write("foo /foo HTTP/1.1\r\n\r\n")
    assert_raises(Syntropy::ProtocolError) { @io.http_read_request_headers }
  end

  def test_http_request_headers_bad_path
    write("get HTTP/1.1\r\n\r\n")
    assert_raises(Syntropy::ProtocolError) { @io.http_read_request_headers }
  end

  def test_http_request_headers_bad_protocol
    write("get / HTTP/1.0\r\n\r\n")
    assert_raises(Syntropy::ProtocolError) { @io.http_read_request_headers }
  end

  def test_http_request_headers_bad_header_missing_value
    write("GET /foo HTTP/1.1\r\nHost: \r\n\r\n")
    assert_raises(Syntropy::ProtocolError) { @io.http_read_request_headers }
  end

  def test_http_request_headers_bad_header
    write("GET /foo HTTP/1.1\r\nHost\r\n\r\n")
    assert_raises(Syntropy::ProtocolError) { @io.http_read_request_headers }
  end

  def test_http_request_with_body_cl
    write("POST /foo HTTP/1.1\r\nContent-Length: 3\r\n\r\nabc")

    h = @io.http_read_request_headers
    assert_equal({
      ':method'         => 'post',
      ':path'           => '/foo',
      'content-length'  => '3'
    }, h)

    b = @io.http_read_body(h)
    assert_equal 'abc', b
  end

  def test_http_request_with_body_te
    write("POST /foo HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n11\r\nabcdefghijKLMNOPQ\r\n3\r\nfoo\r\n0\r\n\r\n")

    h = @io.http_read_request_headers
    assert_equal({
      ':method'           => 'post',
      ':path'             => '/foo',
      'transfer-encoding' => 'chunked'
    }, h)

    b = @io.http_read_body(h)
    assert_equal 'abcdefghijKLMNOPQfoo', b
  end

  def test_http_request_pipelining
    write(
      "GET /a HTTP/1.1\r\n\r\n" +
      "POST /b HTTP/1.1\r\nHost: foo.com\r\nContent-Length: 2\r\n\r\nab" +
      "PATCH /c HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n3\r\nabc\r\n10\r\n#{'*' * 16}\r\n0\r\n\r\n" +
      "GET /d HTTP/1.1\r\nFoo: bar\r\n\r\n"
    )

    reqs = 4.times.map {
      h = @io.http_read_request_headers
      b = @io.http_read_body(h)
      [h, b]
    }

    assert_equal [
      [
        {
          ':method'   => 'get',
          ':path'     => '/a',
        },
        nil
      ],
      [
        {
          ':method'         => 'post',
          ':path'           => '/b',
          'host'            => 'foo.com',
          'content-length'  => '2'
        },
        'ab'
      ],
      [
        {
          ':method'           => 'patch',
          ':path'             => '/c',
          'transfer-encoding' => 'chunked'
        },
        "abc#{'*' * 16}"
      ],
      [
        {
          ':method'   => 'get',
          ':path'     => '/d',
          'foo'       => 'bar'
        },
        nil
      ],
    ], reqs
  end

  def test_http_request_pipelining_skip_body
    write(
      "GET /a HTTP/1.1\r\n\r\n" +
      "POST /b HTTP/1.1\r\nHost: foo.com\r\nContent-Length: 2\r\n\r\nab" +
      "PATCH /c HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n3\r\nabc\r\n10\r\n#{'*' * 16}\r\n0\r\n\r\n" +
      "GET /d HTTP/1.1\r\nFoo: bar\r\n\r\n"
    )

    reqs = 4.times.map {
      h = @io.http_read_request_headers
      @io.http_skip_body(h)
      h
    }

    assert_equal [
      {
        ':method'   => 'get',
        ':path'     => '/a'
      },
      {
        ':method'         => 'post',
        ':path'           => '/b',
        'host'            => 'foo.com',
        'content-length'  => '2'
      },
      {
        ':method'           => 'patch',
        ':path'             => '/c',
        'transfer-encoding' => 'chunked'
      },
      {
        ':method'   => 'get',
        ':path'     => '/d',
        'foo'       => 'bar'
      }
    ], reqs
  end

  def test_http_request_desync1
    write(
      "POST / HTTP/1.1\r\nHost: foo.com\r\nTransfer-Encoding: chunked\r\nContent-length: 35\r\n\r\n0\r\n\r\n" +
      "GET /robots.txt HTTP/1.1\r\nX: y\r\n\r\n"
    )

    h = @io.http_read_request_headers
    assert_equal({
      ':method'           => 'post',
      ':path'             => '/',
      'host'              => 'foo.com',
      'transfer-encoding' => 'chunked',
      'content-length'    => '35'
    }, h)

    @io.http_skip_body(h)

    assert_raises(Syntropy::ProtocolError) { @io.http_read_request_headers }
  end
end

class HTTPProtocolReadChunkTest < HTTPProtocolTest
  def test_http_read_body_chunk_no_body
    write("GET /foo HTTP/1.1\r\Host: bar.baz\r\n\r\n")
    h = @io.http_read_request_headers
    assert_nil @io.http_read_body_chunk(h)
  end

  def test_http_read_body_chunk_cl
    write("POST /foo HTTP/1.1\r\Host: bar.baz\r\nContent-Length: 5\r\n\r\nabcde")
    h = @io.http_read_request_headers
    assert_equal 'abcde', @io.http_read_body_chunk(h)
  end

  def test_http_read_body_chunk_te
    write("POST /foo HTTP/1.1\r\Host: bar.baz\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nabcde\r\n0\r\n\r\n")
    h = @io.http_read_request_headers
    assert_equal 'abcde', @io.http_read_body_chunk(h)
    assert_nil @io.http_read_body_chunk(h)
  end

  def test_http_read_body_chunk_te2
    write("POST /foo HTTP/1.1\r\Host: bar.baz\r\nTransfer-Encoding: chunked\r\n\r\n5\r\nabcde\r\n3\r\nfgh\r\n0\r\n\r\n")
    h = @io.http_read_request_headers
    assert_equal 'abcde', @io.http_read_body_chunk(h)
    assert_equal 'fgh', @io.http_read_body_chunk(h)
    assert_nil @io.http_read_body_chunk(h)
  end
end

class HTTPProtocolResponseTest < HTTPProtocolTest
  def test_http_response_headers_basic
    write("HTTP/1.1 200 OK\r\nHost: bar.baz\r\n\r\n")
    h = @io.http_read_response_headers
    assert_equal({
      ':status' => 200,
      'host'    => 'bar.baz'
    }, h)
  end

  def test_http_response_headers_invalid_status_line1
    write("HTTP 200 OK\r\nHost: bar.baz\r\n\r\n")
    assert_raises(Syntropy::ProtocolError) { @io.http_read_response_headers }
  end

  def test_http_response_headers_invalid_status_line2
    write("HTTP/1.1\r\nHost: bar.baz\r\n\r\n")
    assert_raises(Syntropy::ProtocolError) { @io.http_read_response_headers }
  end

  def test_http_response_headers_invalid_status_line3
    write("HTTP/1.1 ok\r\nBlahblah\r\n\r\n")
    assert_raises(Syntropy::ProtocolError) { @io.http_read_response_headers }
  end
end

class PipelineTest < HTTPProtocolTest
  def test_pipeline_post_zero_content_length
    msg = "POST /counter_api?q=incr HTTP/1.1\r\n" +
          "Host: localhost:1234\r\n" +
          "User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:151.0) Gecko/20100101 Firefox/151.0\r\n" +
          "Accept: */*\r\n" +
          "Accept-Language: en-US,en;q=0.9\r\n" +
          "Accept-Encoding: gzip, deflate, br, zstd\r\n" +
          "Referer: http://localhost:1234/counter\r\n" +
          "Origin: http://localhost:1234\r\n" +
          "Connection: keep-alive\r\n" +
          "Sec-Fetch-Dest: empty\r\n" +
          "Sec-Fetch-Mode: cors\r\n" +
          "Sec-Fetch-Site: same-origin\r\n" +
          "Priority: u=0\r\nPragma: no-cache\r\n" +
          "Cache-Control: no-cache\r\n" +
          "Content-Length: 0\r\n\r\n"

    write(msg * 3)
    3.times {
      h = @io.http_read_request_headers
      assert_equal '*/*', h['accept']
      assert_nil @io.http_read_body_chunk(h)
    }
  end

  def test_pipeline_post_with_body
    msg = "POST /counter_api?q=incr HTTP/1.1\r\n" +
          "Host: localhost:1234\r\n" +
          "User-Agent: Mozilla/5.0 (X11; Linux x86_64; rv:151.0) Gecko/20100101 Firefox/151.0\r\n" +
          "Accept: */*\r\n" +
          "Accept-Language: en-US,en;q=0.9\r\n" +
          "Accept-Encoding: gzip, deflate, br, zstd\r\n" +
          "Referer: http://localhost:1234/counter\r\n" +
          "Origin: http://localhost:1234\r\n" +
          "Connection: keep-alive\r\n" +
          "Sec-Fetch-Dest: empty\r\n" +
          "Sec-Fetch-Mode: cors\r\n" +
          "Sec-Fetch-Site: same-origin\r\n" +
          "Priority: u=0\r\nPragma: no-cache\r\n" +
          "Cache-Control: no-cache\r\n" +
          "Content-Length: 3\r\n\r\n" +
          "abc"

    write(msg * 3)
    3.times {
      h = @io.http_read_request_headers
      assert_equal '*/*', h['accept']
      assert_equal 'abc', @io.http_read_body_chunk(h)
    }

  end
end
