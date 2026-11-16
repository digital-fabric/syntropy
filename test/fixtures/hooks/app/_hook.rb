export ->(req, app) {
  (req.ctx[:hooks] ||= []) << :root
  app.(req)
}
