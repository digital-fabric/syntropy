export ->(req) {
  req.respond("baz: #{req.ctx[:hooks].join(' ')}")
}
