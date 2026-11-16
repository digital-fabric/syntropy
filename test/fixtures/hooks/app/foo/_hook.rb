export ->(req, app) {
  (req.ctx[:hooks] ||= []) << :foo
  app.(req)
}
