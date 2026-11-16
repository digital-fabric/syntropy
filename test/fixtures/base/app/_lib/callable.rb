# frozen_string_literal: true

Klass = import './klass'

def call(x)
  Klass.foo.to_s * x
end

def bar
  @env[:baz]
end

export self
