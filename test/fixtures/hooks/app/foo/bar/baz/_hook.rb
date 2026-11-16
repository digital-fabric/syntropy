export ->(req, app) {
  (req.ctx[:hooks] ||= []) << :baz
  app.(req)
}
