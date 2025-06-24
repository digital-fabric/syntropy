# frozen_string_literal: true

def call(req)
  req.respond('foo')
end
export :call
