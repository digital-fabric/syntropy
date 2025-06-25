# frozen_string_literal: true

require_relative 'helper'

class AppRoutingTest < Minitest::Test
  APP_ROOT = File.join(__dir__, 'app')

  def setup
    @machine = UM.new

    @tmp_path = '/test/tmp'
    @tmp_fn = File.join(APP_ROOT, 'tmp.rb')

    @app = Syntropy::App.new(@machine, APP_ROOT, '/test', watch_files: 0.05)
  end

  def full_path(fn)
    File.join(APP_ROOT, fn)
  end

  def test_find_route
    entry = @app.find_route('/')
    assert_equal :not_found, entry[:kind]

    entry = @app.find_route('/test')
    assert_equal :static, entry[:kind]
    assert_equal full_path('index.html'), entry[:fn]

    entry = @app.find_route('/test/about')
    assert_equal :module, entry[:kind]
    assert_equal full_path('about/index.rb'), entry[:fn]

    entry = @app.find_route('/test/../test_app.rb')
    assert_equal :not_found, entry[:kind]

    entry = @app.find_route('/test/_layout/default')
    assert_equal :not_found, entry[:kind]

    entry = @app.find_route('/test/api')
    assert_equal :module, entry[:kind]
    assert_equal full_path('api+.rb'), entry[:fn]

    entry = @app.find_route('/test/api/foo/bar')
    assert_equal :module, entry[:kind]
    assert_equal full_path('api+.rb'), entry[:fn]

    entry = @app.find_route('/test/api/foo/../bar')
    assert_equal :not_found, entry[:kind]

    entry = @app.find_route('/test/api_1')
    assert_equal :not_found, entry[:kind]

    entry = @app.find_route('/test/about/foo')
    assert_equal :markdown, entry[:kind]
    assert_equal full_path('about/foo.md'), entry[:fn]
  end

  def make_request(*, **)
    req = mock_req(*, **)
    @app.call(req)
    req
  end

  def test_app_rendering
    req = make_request(':method' => 'GET', ':path' => '/')
    assert_equal Qeweney::Status::NOT_FOUND, req.response_status

    req = make_request(':method' => 'GET', ':path' => '/test')
    assert_equal Qeweney::Status::OK, req.response_status
    assert_equal '<h1>Hello, world!</h1>', req.response_body

    req = make_request(':method' => 'GET', ':path' => '/test/index')
    assert_equal '<h1>Hello, world!</h1>', req.response_body

    req = make_request(':method' => 'GET', ':path' => '/test/index.html')
    assert_equal '<h1>Hello, world!</h1>', req.response_body

    req = make_request(':method' => 'GET', ':path' => '/test/assets/style.css')
    assert_equal '* { color: beige }', req.response_body

    req = make_request(':method' => 'GET', ':path' => '/assets/style.css')
    assert_equal Qeweney::Status::NOT_FOUND, req.response_status

    req = make_request(':method' => 'GET', ':path' => '/test/api?q=get')
    assert_equal({ status: 'OK', response: 0 }, req.response_json)

    req = make_request(':method' => 'GET', ':path' => '/test/api/foo?q=get')
    assert_equal({ status: 'OK', response: 0 }, req.response_json)

    req = make_request(':method' => 'POST', ':path' => '/test/api?q=incr')
    assert_equal({ status: 'OK', response: 1 }, req.response_json)

    req = make_request(':method' => 'POST', ':path' => '/test/api/foo?q=incr')
    assert_equal({ status: 'Syntropy::Error', message: 'Teapot' }, req.response_json)
    assert_equal Qeweney::Status::TEAPOT, req.response_status

    req = make_request(':method' => 'GET', ':path' => '/test/bar')
    assert_equal 'foobar', req.response_body

    req = make_request(':method' => 'GET', ':path' => '/test/about')
    assert_equal 'About', req.response_body.chomp

    req = make_request(':method' => 'GET', ':path' => '/test/about/foo')
    assert_equal '<p>Hello from Markdown</p>', req.response_body.chomp

    req = make_request(':method' => 'GET', ':path' => '/test/about/foo/bar')
    assert_equal Qeweney::Status::NOT_FOUND, req.response_status
  end

  def test_app_file_watching
    @machine.sleep 0.2

    req = make_request(':method' => 'GET', ':path' => @tmp_path)
    assert_equal 'foo', req.response_body

    orig_body = IO.read(@tmp_fn)
    IO.write(@tmp_fn, orig_body.gsub('foo', 'bar'))
    @machine.sleep(0.5)

    req = make_request(':method' => 'GET', ':path' => @tmp_path)
    assert_equal 'bar', req.response_body
  ensure
    IO.write(@tmp_fn, orig_body) if orig_body
  end
end
