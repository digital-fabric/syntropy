export ->(req) {
  req.auto_compress!
  req.respond('foobar')
}
