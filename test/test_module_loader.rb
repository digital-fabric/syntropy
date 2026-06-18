# frozen_string_literal: true

require_relative 'helper'

class ModuleTest < Minitest::Test
  def setup
    @machine = UM.new
    @root = File.join(__dir__, 'fixtures/app')
    @env = { app_root: @root, baz: 42, machine: @machine, app: 42 }
    @loader = Syntropy::ModuleLoader.new(@env)
  end

  def test_module_loading
    mod = @loader.load('_lib/klass')
    assert_equal :bar, mod.foo
    assert_equal 42, mod.bar

    assert_raises(Syntropy::Error) { @loader.load('_lib/missing-module') }
    assert_raises(Syntropy::Error) { @loader.load('_lib/missing-export') }

    mod = @loader.load('_lib/callable')
    assert_kind_of Syntropy::ModuleContext, mod
    assert_equal 'barbarbar', mod.call(3)
    assert_raises(NoMethodError) { mod.foo(2) }

    mod = @loader.load('_lib/klass')
    assert_equal :bar, mod.foo
    assert_equal 42, mod.bar
  end

  def test_import_paths
    mod = @loader.load('/mod/path/b')
    assert_kind_of Hash, mod
    assert_equal [:a1, :a2, :foo, :callable], mod.keys

    assert_equal :foo, mod[:a1]
    assert_equal :foo, mod[:a2]
    assert_kind_of Syntropy::ModuleContext, mod[:foo]
    assert_equal 'barbarbar', mod[:callable].(3)
  end

  def test_export_self
    mod = @loader.load('_lib/self')
    assert_kind_of Syntropy::ModuleContext, mod
    assert_equal :bar, mod.foo
  end

  def test_module_env
    mod = @loader.load('_lib/env')

    assert_equal mod, mod.module_const
    assert_equal @env.merge(module_loader: @loader, ref: '/_lib/env'), mod.env
    assert_equal @machine, mod.machine
    assert_equal @loader, mod.module_loader
    assert_equal 42, mod.app

    assert_equal mod, mod.module_const
    assert_equal @env.merge(module_loader: @loader, ref: '/_lib/env'), mod.env
    assert_equal @machine, mod.machine
    assert_equal @loader, mod.module_loader
    assert_equal 42, mod.app
  end

  def test_dependency_invalidation
    _mod = @loader.load('_lib/dep')
    assert_equal ['/_lib/self', '/_lib/dep'], @loader.modules.keys

    self_fn = @loader.modules['/_lib/self'][:fn]
    @loader.invalidate_fn(self_fn)

    assert_equal [], @loader.modules.keys
  end

  def test_index_module_env
    mod = @loader.load('mod/bar/index+')
    assert_equal '/mod/bar', mod.env[:ref]

    mod = @loader.load('mod/foo/index')
    assert_equal '/mod/foo', mod.env[:ref]
  end

  def test_list
    list = @loader.list('_layout')
    assert_equal ['_layout/default'], list

    list = @loader.list('_lib')
    assert_equal [
      '_lib/callable',
      '_lib/dep',
      '_lib/env',
      '_lib/klass',
      '_lib/missing-export',
      '_lib/self',
    ], list

    list = @loader.list('about')
    assert_equal [
      'about/_error',
      'about/index',
      'about/raise'
    ], list

    list = @loader.list('assets')
    assert_equal [], list

    list = @loader.list('mod')
    assert_equal [], list

    list = @loader.list('mod/bar')
    assert_equal ['mod/bar/index+'], list

    list = @loader.list('non-existent')
    assert_equal [], list
  end

  def test_circular_dependency
    assert_raises(Syntropy::Error) { @loader.load('_lib/circular/a') }
    assert_raises(Syntropy::Error) { @loader.load('_lib/circular/b') }
    assert_raises(Syntropy::Error) { @loader.load('_lib/circular/c') }
  end
end


class ModuleExtensionsTest < Minitest::Test
  module E1
    def e1_foo = :foo
  end

  module E2
    def e2_bar = :bar
  end

  module E3
    def e3_baz = :baz
  end

  def test_module_extension_single
    @machine = UM.new
    @root = File.join(__dir__, 'fixtures/app')
    @env = { app_root: @root, baz: 42, machine: @machine, app: 42 }
    @loader = Syntropy::ModuleLoader.new(@env, extensions: E1)

    mod = @loader.load('_lib/self')
    assert_equal true, mod.respond_to?(:e1_foo)
    assert_equal :foo, mod.e1_foo
  end

  def test_module_extension_multi
    @machine = UM.new
    @root = File.join(__dir__, 'fixtures/app')
    @env = { app_root: @root, baz: 42, machine: @machine, app: 42 }
    @loader = Syntropy::ModuleLoader.new(@env, extensions: [E2, E3])

    mod = @loader.load('_lib/self')
    assert_equal true, mod.respond_to?(:e2_bar)
    assert_equal :bar, mod.e2_bar
    assert_equal true, mod.respond_to?(:e3_baz)
    assert_equal :baz, mod.e3_baz
  end
end
