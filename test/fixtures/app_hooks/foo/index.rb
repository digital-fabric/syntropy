export ->(req) {
  req.respond("foo: #{req.ctx[:hooks].join(' ')}")
}
