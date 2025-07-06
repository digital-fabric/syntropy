# frozen_string_literal: true

require_relative 'helper'

class ModuleTest < Minitest::Test
  def setup
    @machine = UM.new
    @root = File.join(__dir__, 'app')
    @env = { baz: 42 }
    @loader = Syntropy::ModuleLoader.new(@root, @env)
  end

  def test_module_loading
    mod = @loader.load('_lib/klass')
    assert_equal :bar, mod.foo
    assert_equal 42, mod.bar

    assert_raises(RuntimeError) { @loader.load('_lib/foo') }
    assert_raises(RuntimeError) { @loader.load('_lib/missing-export') }

    mod = @loader.load('_lib/callable')
    assert_kind_of Proc, mod
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
end
