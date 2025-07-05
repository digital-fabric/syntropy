export ->(req, proc) {
  req.ctx[:foo] = req.query[:foo]
  proc.(req)
}
