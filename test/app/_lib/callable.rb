# frozen_string_literal: true

Klass = import '_lib/klass'

def call(x)
  Klass.foo.to_s * x
end

def bar
  @env[:baz]
end

export self
