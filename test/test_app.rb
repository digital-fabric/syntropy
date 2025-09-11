# frozen_string_literal: true

require_relative 'helper'

class AppTest < Minitest::Test
  Status = Qeweney::Status

  APP_ROOT = File.join(__dir__, 'app')

  def setup
    @machine = UM.new

    @tmp_path = '/test/tmp'
    @tmp_fn = File.join(APP_ROOT, 'tmp.rb')

    @app = Syntropy::App.new(
      root_dir: APP_ROOT,
      mount_path: '/test',
      watch_files: 0.05,
      machine: @machine
    )
  end

  def make_request(*, **)
    req = mock_req(*, **)
    @app.call(req)
    req
  end

  def test_app_rendering
    req = make_request(':method' => 'GET', ':path' => '/')
    assert_equal Status::NOT_FOUND, req.response_status
    assert_equal 'Not found', req.response_body

    req = make_request(':method' => 'HEAD', ':path' => '/')
    assert_equal Status::NOT_FOUND, req.response_status
    assert_nil req.response_body

    req = make_request(':method' => 'POST', ':path' => '/')
    assert_equal 'Not found', req.response_body
    assert_equal Status::NOT_FOUND, req.response_status

    req = make_request(':method' => 'GET', ':path' => '/test')
    assert_equal Status::OK, req.response_status
    assert_equal '<h1>Hello, world!</h1>', req.response_body

    req = make_request(':method' => 'HEAD', ':path' => '/test')
    assert_equal Status::OK, req.response_status
    assert_nil req.response_body

    req = make_request(':method' => 'POST', ':path' => '/test')
    assert_equal Status::METHOD_NOT_ALLOWED, req.response_status
    assert_nil req.response_body

    req = make_request(':method' => 'GET', ':path' => '/test/assets/style.css')
    assert_equal '* { color: beige }', req.response_body
    assert_equal 'text/css', req.response_headers['Content-Type']

    req = make_request(':method' => 'GET', ':path' => '/assets/style.css')
    assert_equal Status::NOT_FOUND, req.response_status

    req = make_request(':method' => 'GET', ':path' => '/test/api?q=get')
    assert_equal({ status: 'OK', response: 0 }, req.response_json)

    req = make_request(':method' => 'POST', ':path' => '/test/api?q=get')
    assert_equal Status::METHOD_NOT_ALLOWED, req.response_status
    assert_equal({ status: 'Error', message: '' }, req.response_json)

    req = make_request(':method' => 'GET', ':path' => '/test/api/foo?q=get')
    assert_equal({ status: 'OK', response: 0 }, req.response_json)

    req = make_request(':method' => 'POST', ':path' => '/test/api?q=incr')
    assert_equal({ status: 'OK', response: 1 }, req.response_json)

    req = make_request(':method' => 'GET', ':path' => '/test/api?q=incr')
    assert_equal Status::METHOD_NOT_ALLOWED, req.response_status
    assert_equal({ status: 'Error', message: '' }, req.response_json)

    req = make_request(':method' => 'POST', ':path' => '/test/api/foo?q=incr')
    assert_equal({ status: 'Error', message: 'Teapot' }, req.response_json)
    assert_equal Status::TEAPOT, req.response_status

    req = make_request(':method' => 'POST', ':path' => '/test/api/foo/bar?q=incr')
    assert_equal({ status: 'Error', message: 'Teapot' }, req.response_json)
    assert_equal Status::TEAPOT, req.response_status

    req = make_request(':method' => 'GET', ':path' => '/test/bar')
    assert_equal 'foobar', req.response_body
    assert_equal Status::OK, req.response_status

    req = make_request(':method' => 'POST', ':path' => '/test/bar')
    assert_equal 'foobar', req.response_body
    assert_equal Status::OK, req.response_status

    req = make_request(':method' => 'GET', ':path' => '/test/baz')
    assert_equal 'foobar', req.response_body
    assert_equal Status::OK, req.response_status

    req = make_request(':method' => 'POST', ':path' => '/test/baz')
    assert_nil req.response_body
    assert_equal Status::METHOD_NOT_ALLOWED, req.response_status

    req = make_request(':method' => 'GET', ':path' => '/test/about')
    assert_equal 'About', req.response_body.chomp

    req = make_request(':method' => 'GET', ':path' => '/test/about/foo')
    assert_equal '<p>Hello from Markdown</p>', req.response_body.chomp

    req = make_request(':method' => 'HEAD', ':path' => '/test/about/foo')
    assert_nil req.response_body

    req = make_request(':method' => 'GET', ':path' => '/test/about/foo/bar')
    assert_equal Status::NOT_FOUND, req.response_status

    req = make_request(':method' => 'GET', ':path' => '/test/params/abc')
    assert_equal '/test/params/[foo]-abc', req.response_body.chomp

    req = make_request(':method' => 'GET', ':path' => '/test/rss')
    assert_equal '<link>foo</link>', req.response_body

  end

  def test_app_file_watching
    @machine.sleep 0.3

    req = make_request(':method' => 'GET', ':path' => @tmp_path)
    assert_equal 'foo', req.response_body

    orig_body = IO.read(@tmp_fn)
    IO.write(@tmp_fn, orig_body.gsub('foo', 'bar'))
    @machine.sleep(0.3)

    req = make_request(':method' => 'GET', ':path' => @tmp_path)
    assert_equal 'bar', req.response_body
  ensure
    IO.write(@tmp_fn, orig_body) if orig_body
  end

  def test_middleware
    req = make_request(':method' => 'HEAD', ':path' => '/test?foo=42')
    assert_equal Status::OK, req.response_status
    assert_nil req.response_body
    assert_equal '42', req.ctx[:foo]

    req = make_request(':method' => 'HEAD', ':path' => '/test/about/raise?foo=43')
    assert_equal Status::INTERNAL_SERVER_ERROR, req.response_status
    assert_equal '<h1>Raised error</h1>', req.response_body
    assert_equal '43', req.ctx[:foo]
  end
end

class CustomAppTest < Minitest::Test
  Status = Qeweney::Status

  APP_ROOT = File.join(__dir__, 'app_custom')

  def setup
    @machine = UM.new
    @app = Syntropy::App.load(
      machine: @machine,
      root_dir: APP_ROOT,
      mount_path: '/'
    )
  end

  def make_request(*, **)
    req = mock_req(*, **)
    @app.call(req)
    req
  end

  def test_app_with_site_rb_file
    req = make_request(':method' => 'GET', ':path' => '/foo/bar')
    assert_nil req.response_body
    assert_equal Status::TEAPOT, req.response_status
  end
end

class MultiSiteAppTest < Minitest::Test
  Status = Qeweney::Status

  APP_ROOT = File.join(__dir__, 'app_multi_site')

  def setup
    @machine = UM.new
    @app = Syntropy::App.load(
      machine: @machine,
      root_dir: APP_ROOT,
      mount_path: '/'
    )
  end

  def make_request(*, **)
    req = mock_req(*, **)
    @app.call(req)
    req
  end

  def test_route_by_host
    req = make_request(':method' => 'GET', ':path' => '/', 'host' => 'blah')
    assert_nil req.response_body
    assert_equal Status::BAD_REQUEST, req.response_status

    req = make_request(':method' => 'GET', ':path' => '/', 'host' => 'foo.bar')
    assert_equal '<h1>foo.bar</h1>', req.response_body.chomp

    req = make_request(':method' => 'GET', ':path' => '/', 'host' => 'bar.baz')
    assert_equal '<h1>bar.baz</h1>', req.response_body.chomp
  end
end
