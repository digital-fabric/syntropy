export ->(req) {
  req.respond("bar: #{req.ctx[:hooks].join(' ')}")
}
