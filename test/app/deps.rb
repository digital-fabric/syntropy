export ->(req) {
  req.respond(@env[:foo][:foo] + @env[:bar][:bar])
}
