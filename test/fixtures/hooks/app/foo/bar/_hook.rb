export ->(req, app) {
  (req.ctx[:hooks] ||= []) << :bar
  app.(req)
}
