class Klass
  def initialize(env)
    @env = env
  end

  def foo
    :bar
  end

  def bar
    @env[:baz]
  end
end

export Klass
