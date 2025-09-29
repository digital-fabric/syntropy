# frozen_string_literal: true

require_relative 'helper'

class ModuleTest < Minitest::Test
  def setup
    @machine = UM.new
    @root = File.join(__dir__, 'app')
    @env = { root_dir: @root, baz: 42, machine: @machine, app: 42 }
    @loader = Syntropy::ModuleLoader.new(@env)
  end

  def test_module_loading
    mod = @loader.load('_lib/klass')
    assert_equal :bar, mod.foo
    assert_equal 42, mod.bar

    assert_raises(Syntropy::Error) { @loader.load('_lib/missing-module') }
    assert_raises(Syntropy::Error) { @loader.load('_lib/missing-export') }

    mod = @loader.load('_lib/callable')
    assert_kind_of Syntropy::Module, mod
    assert_equal 'barbarbar', mod.call(3)
    assert_raises(NoMethodError) { mod.foo(2) }

    mod = @loader.load('_lib/klass')
    assert_equal :bar, mod.foo
    @env[:baz] += 1
    assert_equal 43, mod.bar
  end

  def test_export_self
    mod = @loader.load('_lib/self')
    assert_kind_of Syntropy::Module, mod
    assert_equal :bar, mod.foo
  end

  def test_module_env
    mod = @loader.load('_lib/env')

    assert_equal mod, mod.module_const
    assert_equal @env.merge(module_loader: @loader, ref: '_lib/env'), mod.env
    assert_equal @machine, mod.machine
    assert_equal @loader, mod.module_loader
    assert_equal 42, mod.app

    assert_equal mod, mod.module_const
    assert_equal @env.merge(module_loader: @loader, ref: '_lib/env'), mod.env
    assert_equal @machine, mod.machine
    assert_equal @loader, mod.module_loader
    assert_equal 42, mod.app
  end

  def test_dependency_invalidation
    mod = @loader.load('_lib/dep')
    assert_equal ['_lib/self', '_lib/dep'], @loader.modules.keys

    self_fn = @loader.modules['_lib/self'][:fn]
    @loader.invalidate_fn(self_fn)

    assert_equal [], @loader.modules.keys
  end

  def test_index_module_env
    mod = @loader.load('mod/bar/index+')
    assert_equal 'mod/bar', mod.env[:ref]

    mod = @loader.load('mod/foo/index')
    assert_equal 'mod/foo', mod.env[:ref]
  end
end
