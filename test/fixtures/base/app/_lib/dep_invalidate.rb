Foo = import '/_lib/self'

invalidate_on_file_change('circular/**')

export self
