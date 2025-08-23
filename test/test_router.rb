# frozen_string_literal: true

require_relative 'helper'

class RouterTest < Minitest::Test
  APP_ROOT = File.join(__dir__, 'app')

  def setup
    @machine = UM.new

    @tmp_path = '/test/tmp'
    @tmp_fn = File.join(APP_ROOT, 'tmp.rb')

    @router = Syntropy::Router.new(
      machine: @machine,
      location: APP_ROOT,
      mount_path: '/test',
      watch_files: 0.05
    )
    @router.start_file_watcher
  end

  def full_path(fn)
    File.join(APP_ROOT, fn)
  end

  def test_routing
    entry = @router['/test']
    assert_equal :static, entry[:kind]
    assert_equal full_path('index.html'), entry[:fn]

    entry = @router['/test/about']
    assert_equal :module, entry[:kind]
    assert_equal full_path('about/index.rb'), entry[:fn]

    entry = @router['/test/../test_app.rb']
    assert_equal :not_found, entry[:kind]

    entry = @router['/test/_layout/default']
    assert_equal :not_found, entry[:kind]

    entry = @router['/test/api']
    assert_equal :module, entry[:kind]
    assert_equal full_path('api+.rb'), entry[:fn]

    entry = @router['/test/api/foo/bar']
    assert_equal :module, entry[:kind]
    assert_equal full_path('api+.rb'), entry[:fn]

    entry = @router['/test/api//foo/bar']
    assert_equal :not_found, entry[:kind]

    entry = @router['/test/api/foo/../bar']
    assert_equal :not_found, entry[:kind]

    entry = @router['/test/api_1']
    assert_equal :not_found, entry[:kind]

    entry = @router['/test/about/foo']
    assert_equal :markdown, entry[:kind]
    assert_equal full_path('about/foo.md'), entry[:fn]
  end

  def test_router_file_watching
    @machine.sleep 0.2

    entry = @router[@tmp_path]
    assert_equal :module, entry[:kind]

    # remove file
    orig_body = IO.read(@tmp_fn)
    FileUtils.rm(@tmp_fn)
    @machine.sleep(0.3)

    entry = @router[@tmp_path]
    assert_equal :not_found, entry[:kind]

    IO.write(@tmp_fn, 'foobar')
    @machine.sleep(0.3)
    entry = @router[@tmp_path]
    assert_equal :module, entry[:kind]

    entry[:proc] = ->(x) { x }
    IO.write(@tmp_fn, 'barbaz')
    @machine.sleep(0.3)
    assert_nil entry[:proc]
  ensure
    IO.write(@tmp_fn, orig_body) if orig_body
  end

  def test_malformed_path_routing
    entry = @router['//xmlrpc.php?rsd']
    assert_equal :not_found, entry[:kind]

    entry = @router['/test//xmlrpc.php?rsd']
    assert_equal :not_found, entry[:kind]

    entry = @router['/test///xmlrpc.php?rsd']
    assert_equal :not_found, entry[:kind]

    entry = @router['/test///xmlrpc.php?rsd']
    assert_equal :not_found, entry[:kind]

    entry = @router['/test/./qsdf']
    assert_equal :not_found, entry[:kind]

    entry = @router['/test/../../lib/syntropy.rb']
    assert_equal :not_found, entry[:kind]

    entry = @router['/../../lib/syntropy.rb']
    assert_equal :not_found, entry[:kind]
  end
end
