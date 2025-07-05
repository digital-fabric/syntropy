export ->(req, proc) {
  req.ctx[:foo] = req.query[:foo]
  # p proc: proc
  proc.(req)
}
