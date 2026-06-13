# frozen_string_literal: true

require_relative 'helper'

class AppTest < Minitest::Test
  HTTP = Syntropy::HTTP

  APP_ROOT = File.join(__dir__, 'fixtures/app')

  def setup
    @machine = UM.new

    @tmp_path = '/test/tmp'
    @tmp_fn = File.join(APP_ROOT, 'tmp.rb')

    @app = Syntropy::App.new(
      app_root: APP_ROOT,
      mount_path: '/test',
      watch_files: 0.05,
      machine: @machine
    )

    @test_harness = Syntropy::TestHarness.new(@app)
  end

  def test_app_rendering
    req = @test_harness.request(':method' => 'GET', ':path' => '/')
    assert_equal HTTP::NOT_FOUND, req.response_status
    assert_equal 'Not found', req.response_body

    req = @test_harness.request(':method' => 'HEAD', ':path' => '/')
    assert_equal HTTP::NOT_FOUND, req.response_status
    assert_nil req.response_body

    req = @test_harness.request(':method' => 'POST', ':path' => '/')
    assert_equal 'Not found', req.response_body
    assert_equal HTTP::NOT_FOUND, req.response_status

    req = @test_harness.request(':method' => 'GET', ':path' => '/test')
    assert_equal HTTP::OK, req.response_status
    assert_equal '<h1>Hello, world!</h1>', req.response_body

    req = @test_harness.request(':method' => 'HEAD', ':path' => '/test')
    assert_equal HTTP::OK, req.response_status
    assert_nil req.response_body

    req = @test_harness.request(':method' => 'POST', ':path' => '/test')
    assert_equal HTTP::METHOD_NOT_ALLOWED, req.response_status
    assert_equal "Method not allowed", req.response_body

    req = @test_harness.request(':method' => 'GET', ':path' => '/test/assets/style.css')
    assert_equal '* { color: beige }', req.response_body
    assert_equal 'text/css', req.response_headers['Content-Type']

    req = @test_harness.request(':method' => 'GET', ':path' => '/assets/style.css')
    assert_equal HTTP::NOT_FOUND, req.response_status

    req = @test_harness.request(':method' => 'GET', ':path' => '/test/api?q=get')
    assert_equal({ 'status' => 'OK', 'response' => 0 }, req.response_json)

    req = @test_harness.request(':method' => 'POST', ':path' => '/test/api?q=get')
    assert_equal HTTP::METHOD_NOT_ALLOWED, req.response_status
    assert_equal({ 'status' => 'Error', 'message' => 'Method not allowed' }, req.response_json)

    req = @test_harness.request(':method' => 'GET', ':path' => '/test/api/foo?q=get')
    assert_equal({ 'status' => 'OK', 'response' => 0 }, req.response_json)

    req = @test_harness.request(':method' => 'POST', ':path' => '/test/api?q=incr')
    assert_equal({ 'status' => 'OK', 'response' => 1 }, req.response_json)

    req = @test_harness.request(':method' => 'GET', ':path' => '/test/api?q=incr')
    assert_equal HTTP::METHOD_NOT_ALLOWED, req.response_status
    assert_equal({ 'status' => 'Error', 'message' => 'Method not allowed' }, req.response_json)

    req = @test_harness.request(':method' => 'POST', ':path' => '/test/api/foo?q=incr')
    assert_equal({ 'status' => 'Error', 'message' => 'Teapot' }, req.response_json)
    assert_equal HTTP::TEAPOT, req.response_status

    req = @test_harness.request(':method' => 'POST', ':path' => '/test/api/foo/bar?q=incr')
    assert_equal({ 'status' => 'Error', 'message' => 'Teapot' }, req.response_json)
    assert_equal HTTP::TEAPOT, req.response_status

    req = @test_harness.request(':method' => 'GET', ':path' => '/test/bar')
    assert_equal 'foobar', req.response_body
    assert_equal HTTP::OK, req.response_status

    req = @test_harness.request(':method' => 'POST', ':path' => '/test/bar')
    assert_equal 'foobar', req.response_body
    assert_equal HTTP::OK, req.response_status

    req = @test_harness.request(':method' => 'GET', ':path' => '/test/baz')
    assert_equal 'foobar', req.response_body
    assert_equal HTTP::OK, req.response_status

    req = @test_harness.request(':method' => 'POST', ':path' => '/test/baz')
    assert_equal 'Method not allowed', req.response_body
    assert_equal HTTP::METHOD_NOT_ALLOWED, req.response_status

    req = @test_harness.request(':method' => 'GET', ':path' => '/test/about')
    assert_equal 'About', req.response_body.chomp

    req = @test_harness.request(':method' => 'GET', ':path' => '/test/about/foo')
    assert_equal '<!DOCTYPE html><html><head><title></title></head><body><p>Hello from Markdown</p></body></html>', req.response_body.gsub(/\n/, '')

    req = @test_harness.request(':method' => 'HEAD', ':path' => '/test/about/foo')
    assert_nil req.response_body

    req = @test_harness.request(':method' => 'GET', ':path' => '/test/about/foo/bar')
    assert_equal HTTP::NOT_FOUND, req.response_status

    req = @test_harness.request(':method' => 'GET', ':path' => '/test/params/abc')
    assert_equal '/test/params/[foo]-abc', req.response_body.chomp

    req = @test_harness.request(':method' => 'GET', ':path' => '/test/rss')
    assert_equal '<link>foo</link>', req.response_body

    req = @test_harness.no_raise_internal_server_error {
      @test_harness.request(':method' => 'GET', ':path' => '/test/bad_mod')
    }
    assert_equal HTTP::INTERNAL_SERVER_ERROR, req.response_status

    req = @test_harness.no_raise_internal_server_error {
      @test_harness.request(':method' => 'GET', ':path' => '/test/bad_mod_arity')
    }
    assert_equal HTTP::INTERNAL_SERVER_ERROR, req.response_status

    req = @test_harness.request(':method' => 'GET', ':path' => '/test/.well-known/foo')
    assert_equal HTTP::OK, req.response_status
    assert_equal 'foo', req.response_body

    req = @test_harness.request(':method' => 'GET', ':path' => '/test/by_method')
    assert_equal HTTP::OK, req.response_status
    assert_equal 'foo', req.response_body

    req = @test_harness.request(':method' => 'POST', ':path' => '/test/by_method')
    assert_equal HTTP::OK, req.response_status
    assert_equal 'bar', req.response_body

    req = @test_harness.request(':method' => 'DELETE', ':path' => '/test/by_method')
    assert_equal HTTP::METHOD_NOT_ALLOWED, req.response_status

    req = @test_harness.request(':method' => 'GET', ':path' => '/test/http')
    assert_equal HTTP::TEAPOT, req.response_status
  end

  def test_automatic_redirect_on_trailing_slash
    req = @test_harness.request(':method' => 'GET', ':path' => '/test/rss/')
    assert_equal HTTP::MOVED_PERMANENTLY, req.response_status
    assert_equal '/test/rss', req.response_headers['Location']
  end

  def test_app_file_watching
    @machine.sleep 0.2

    req = @test_harness.request(':method' => 'GET', ':path' => @tmp_path)
    assert_equal 'foo', req.response_body

    orig_body = IO.read(@tmp_fn)
    IO.write(@tmp_fn, orig_body.gsub('foo', 'bar'))
    @machine.sleep(0.2)

    req = @test_harness.request(':method' => 'GET', ':path' => @tmp_path)
    assert_equal 'bar', req.response_body
  ensure
    IO.write(@tmp_fn, orig_body) if orig_body
  end

  def test_middleware
    req = @test_harness.request(':method' => 'HEAD', ':path' => '/test?foo=42')
    assert_equal HTTP::OK, req.response_status
    assert_nil req.response_body
    assert_equal '42', req.ctx[:foo]

    req = @test_harness.request(':method' => 'HEAD', ':path' => '/test/about/raise?foo=43')
    assert_equal HTTP::INTERNAL_SERVER_ERROR, req.response_status
    assert_equal '<h1>Raised error</h1>', req.response_body
    assert_equal '43', req.ctx[:foo]
  end

  def test_middleware_invocation_on_404
    req = @test_harness.request(':method' => 'HEAD', ':path' => '/azerty?foo=bar')
    assert_equal HTTP::NOT_FOUND, req.response_status
    assert_nil req.ctx[:foo]

    req = @test_harness.request(':method' => 'HEAD', ':path' => '/test/azerty?foo=bar')
    assert_equal HTTP::NOT_FOUND, req.response_status
    assert_equal 'bar', req.ctx[:foo]
  end
end

class MiddlewareHooksTest < Minitest::Test
  HTTP = Syntropy::HTTP

  APP_ROOT = File.join(__dir__, 'fixtures/app_hooks')

  def setup
    @machine = UM.new

    @tmp_path = '/test/tmp'
    @tmp_fn = File.join(APP_ROOT, 'tmp.rb')

    @app = Syntropy::App.new(
      app_root: APP_ROOT,
      mount_path: '/',
      watch_files: 0.05,
      machine: @machine
    )

    @test_harness = Syntropy::TestHarness.new(@app)
  end

  def test_middleware_composition
    req = @test_harness.request(':method' => 'GET', ':path' => '/')
    assert_equal HTTP::OK, req.response_status
    assert_equal 'root: root', req.response_body

    req = @test_harness.request(':method' => 'GET', ':path' => '/foo')
    assert_equal HTTP::OK, req.response_status
    assert_equal 'foo: root foo', req.response_body

    req = @test_harness.request(':method' => 'GET', ':path' => '/foo/bar')
    assert_equal HTTP::OK, req.response_status
    assert_equal 'bar: root foo bar', req.response_body

    req = @test_harness.request(':method' => 'GET', ':path' => '/foo/bar/baz')
    assert_equal HTTP::OK, req.response_status
    assert_equal 'baz: root foo bar baz', req.response_body
  end
end

class ErrorHandlerTest < Minitest::Test
  HTTP = Syntropy::HTTP

  APP_ROOT = File.join(__dir__, 'fixtures/app_errors')

  def setup
    @machine = UM.new

    @tmp_path = '/test/tmp'
    @tmp_fn = File.join(APP_ROOT, 'tmp.rb')

    @app = Syntropy::App.new(
      app_root: APP_ROOT,
      mount_path: '/',
      watch_files: 0.05,
      machine: @machine
    )

    @test_harness = Syntropy::TestHarness.new(@app)
  end

  def test_error_handlers
    req = @test_harness.request(':method' => 'GET', ':path' => '/')
    assert_equal HTTP::TEAPOT, req.response_status
    assert_equal 'root: root', req.response_body

    req = @test_harness.request(':method' => 'GET', ':path' => '/foo')
    assert_equal HTTP::TEAPOT, req.response_status
    assert_equal 'foo: foo', req.response_body

    req = @test_harness.request(':method' => 'GET', ':path' => '/foo/bar')
    assert_equal HTTP::TEAPOT, req.response_status
    assert_equal 'bar: bar', req.response_body

    req = @test_harness.request(':method' => 'GET', ':path' => '/foo/bar/baz')
    assert_equal HTTP::TEAPOT, req.response_status
    assert_equal 'bar: baz', req.response_body
  end
end

class CustomAppTest < Minitest::Test
  HTTP = Syntropy::HTTP

  APP_ROOT = File.join(__dir__, 'fixtures/app_custom')

  def setup
    @machine = UM.new
    @app = Syntropy::App.load(
      machine: @machine,
      app_root: APP_ROOT,
      mount_path: '/'
    )
    @test_harness = Syntropy::TestHarness.new(@app)
  end

  def test_app_with_site_rb_file
    req = @test_harness.request(':method' => 'GET', ':path' => '/foo/bar')
    assert_nil req.response_body
    assert_equal HTTP::TEAPOT, req.response_status
  end
end

class MultiSiteAppTest < Minitest::Test
  HTTP = Syntropy::HTTP

  APP_ROOT = File.join(__dir__, 'fixtures/app_multi_site')

  def setup
    @machine = UM.new
    @app = Syntropy::App.load(
      machine: @machine,
      app_root: APP_ROOT,
      mount_path: '/'
    )
    @test_harness = Syntropy::TestHarness.new(@app)
  end

  def test_dispatch_by_host
    req = @test_harness.request(':method' => 'GET', ':path' => '/', 'host' => 'blah')
    assert_nil req.response_body
    assert_equal HTTP::BAD_REQUEST, req.response_status

    req = @test_harness.request(':method' => 'GET', ':path' => '/', 'host' => 'foo.bar')
    assert_equal '<h1>foo.bar</h1>', req.response_body.chomp

    req = @test_harness.request(':method' => 'GET', ':path' => '/', 'host' => 'bar.baz')
    assert_equal '<h1>bar.baz</h1>', req.response_body.chomp
  end
end

class AppAPITest < Minitest::Test
  HTTP = Syntropy::HTTP

  APP_ROOT = File.join(__dir__, 'fixtures/app')

  def setup
    @machine = UM.new

    @tmp_path = '/test/tmp'
    @tmp_fn = File.join(APP_ROOT, 'tmp.rb')

    @app = Syntropy::App.new(
      app_root: APP_ROOT,
      mount_path: '/test',
      watch_files: 0.05,
      machine: @machine
    )
  end

  def test_route_method
    route = @app.route('/')
    assert_nil route

    route = @app.route('/', compute_proc: true)
    assert_nil route

    route = @app.route('/test')
    assert_nil route[:parent]
    assert_equal '/test', route[:path]
    assert_equal :static, route[:target][:kind]
    assert_equal File.join(APP_ROOT, 'index.html'), route[:target][:fn]

    route = @app.route('/test/assets/style.css')
    assert_equal '/test/assets', route[:parent][:path]
    assert_equal :static, route[:target][:kind]
    assert_equal File.join(APP_ROOT, 'assets/style.css'), route[:target][:fn]

    route = @app.route('/test/api')
    assert_equal '/test', route[:parent][:path]
    assert_equal :module, route[:target][:kind]
    assert_equal File.join(APP_ROOT, 'api+.rb'), route[:target][:fn]

    route = @app.route('/test/api/foo')
    assert_equal '/test', route[:parent][:path]
    assert_equal :module, route[:target][:kind]
    assert_equal File.join(APP_ROOT, 'api+.rb'), route[:target][:fn]

    route = @app.route('/test/bar')
    assert_equal '/test', route[:parent][:path]
    assert_equal :module, route[:target][:kind]
    assert_equal File.join(APP_ROOT, 'bar.rb'), route[:target][:fn]

    route = @app.route('/test/about/raise')
    assert_equal '/test/about', route[:parent][:path]
    assert_equal :module, route[:target][:kind]
    assert_equal File.join(APP_ROOT, 'about/raise.rb'), route[:target][:fn]

    route = @app.route('/test/about/foo')
    assert_equal '/test/about', route[:parent][:path]
    assert_equal :markdown, route[:target][:kind]
    assert_equal File.join(APP_ROOT, 'about/foo.md'), route[:target][:fn]
  end
end

class AppDependenciesTest < Minitest::Test
  HTTP = Syntropy::HTTP

  APP_ROOT = File.join(__dir__, 'fixtures/app')

  def test_app_dependencies
    foo = { foo: 'foo' }
    bar = { bar: 'bar' }

    @machine = UM.new

    @tmp_path = '/test/tmp'
    @tmp_fn = File.join(APP_ROOT, 'tmp.rb')

    @app = Syntropy::App.new(
      app_root: APP_ROOT,
      mount_path: '/test',
      machine: @machine,
      foo: foo,
      bar: bar
    )
    @test_harness = Syntropy::TestHarness.new(@app)

    req = @test_harness.request(':method' => 'GET', ':path' => '/test/bar')
    assert_equal 'foobar', req.response_body
    assert_equal HTTP::OK, req.response_status
  end
end
