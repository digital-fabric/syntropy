Foo = import '/_lib/self'

def bar
  Foo.foo
end

export self
