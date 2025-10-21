# frozen_string_literal: true

a1 = import './a'
a2 = import 'a'
foo = import '../foo/index'
callable = import '/_lib/callable'

export(a1:, a2:, foo:, callable:)
