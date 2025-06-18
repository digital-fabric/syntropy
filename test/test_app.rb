# frozen_string_literal: true

require_relative 'helper'

class AppRoutingTest < Minitest::Test
  APP_ROOT = File.join(__dir__, 'app')

  def setup
    @app = Syntropy::App.new(APP_ROOT, '/test')
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

    pp @app.route_cache
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
  end
end
