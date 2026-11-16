export ->(req) {
  req.respond("root: #{req.ctx[:hooks].join(' ')}")
}
